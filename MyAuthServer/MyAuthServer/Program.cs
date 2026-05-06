using Microsoft.EntityFrameworkCore;
using Konscious.Security.Cryptography;
using System.Text;
using System.Security.Cryptography;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(opt => opt.AddPolicy("AllowAll", p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

var app = builder.Build();
app.UseCors("AllowAll");

// КЛЮЧ ДЛЯ ШИФРОВАНИЯ ФИО
byte[] key = Encoding.UTF8.GetBytes("A67890B234567890C1234567890D1234");

byte[] EncryptFio(string text)
{
    using var aes = Aes.Create();
    aes.Key = key;
    aes.GenerateIV();
    using var encryptor = aes.CreateEncryptor();
    var plainBytes = Encoding.UTF8.GetBytes(text);
    var encrypted = encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);
    return aes.IV.Concat(encrypted).ToArray();
}

string DecryptFio(byte[] data)
{
    using var aes = Aes.Create();
    aes.Key = key;
    var iv = data.Take(16).ToArray();
    var encrypted = data.Skip(16).ToArray();
    using var decryptor = aes.CreateDecryptor(aes.Key, iv);
    var result = decryptor.TransformFinalBlock(encrypted, 0, encrypted.Length);
    return Encoding.UTF8.GetString(result);
}

// ВСПОМОГАТЕЛЬНЫЙ МЕТОД ДЛЯ ХЕШИРОВАНИЯ ПАРОЛЯ
async Task<(string hash, string salt)> HashPassword(string password)
{
    var salt = RandomNumberGenerator.GetBytes(16);
    var argon2 = new Argon2id(Encoding.UTF8.GetBytes(password))
    {
        Salt = salt,
        DegreeOfParallelism = 4,
        Iterations = 2,
        MemorySize = 1024
    };
    var hash = await argon2.GetBytesAsync(16);
    return (Convert.ToBase64String(hash), Convert.ToBase64String(salt));
}

// АВТОРИЗАЦИЯ
app.MapPost("/login", async (string username, string password, AppDbContext db) => {
    var user = await db.Users.FirstOrDefaultAsync(x => x.Username == username);
    if (user == null) return Results.Unauthorized();

    var argon2 = new Argon2id(Encoding.UTF8.GetBytes(password))
    {
        Salt = Convert.FromBase64String(user.Salt),
        DegreeOfParallelism = 4,
        Iterations = 2,
        MemorySize = 1024
    };
    var isOk = Convert.ToBase64String(await argon2.GetBytesAsync(16)) == user.PasswordHash;
    return isOk ? Results.Ok(new { user.Id, user.Role_Id, user.Pck_Id, user.CreatedBy }) : Results.Unauthorized();
});

// ==================== GET ВСЕХ ТАБЛИЦ ====================
app.MapGet("/roles", async (AppDbContext db) => await db.Roles.ToListAsync());
app.MapGet("/users", async (AppDbContext db) => {
    var users = await db.Users.ToListAsync();
    return users.Select(u => new {
        u.Id,
        u.Username,
        u.Role_Id,
        u.Pck_Id,
        u.CreatedBy
    });
});
app.MapGet("/pck", async (AppDbContext db) => await db.PCKs.ToListAsync());
app.MapGet("/positions", async (AppDbContext db) => await db.Positions.ToListAsync());
app.MapGet("/degrees", async (AppDbContext db) => await db.Degrees.ToListAsync());
app.MapGet("/employments", async (AppDbContext db) => await db.Employments.ToListAsync());
app.MapGet("/specialties", async (AppDbContext db) => await db.Specialties.ToListAsync());
app.MapGet("/curriculums", async (AppDbContext db) => await db.Curriculums.ToListAsync());
app.MapGet("/groups", async (AppDbContext db) => await db.Groups.ToListAsync());
app.MapGet("/discipline-cycles", async (AppDbContext db) => await db.DisciplineCycles.ToListAsync());
app.MapGet("/disciplines", async (AppDbContext db) => await db.Disciplines.ToListAsync());
app.MapGet("/curriculum-load", async (AppDbContext db) => await db.CurriculumLoads.ToListAsync());
app.MapGet("/teachers", async (AppDbContext db) => {
    var list = await db.Teachers.ToListAsync();
    return list.Select(t => new {
        t.Id_Teacher,
        Fio = DecryptFio(t.Fio),
        t.User_Id,
        t.PCK_Id,
        t.Position_Id,
        t.Degree_Id,
        t.Employment_Id,
        t.KN_Number,
        t.Category,
        t.Has_Higher_Education
    });
});
app.MapGet("/academic-years", async (AppDbContext db) => await db.AcademicYears.ToListAsync());
app.MapGet("/group-academic-years", async (AppDbContext db) => await db.GroupAcademicYears.ToListAsync());
app.MapGet("/actual-load", async (AppDbContext db) => await db.ActualLoads.ToListAsync());

// ==================== POST ДОБАВЛЕНИЕ ====================
app.MapPost("/roles", async (Role item, AppDbContext db) => { db.Roles.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });

app.MapPost("/users", async (UserCreateDto dto, AppDbContext db) => {
    var (hash, salt) = await HashPassword(dto.Password);

    var user = new User
    {
        Username = dto.Username,
        PasswordHash = hash,
        Salt = salt,
        Role_Id = dto.Role_Id,
        Pck_Id = dto.Pck_Id,
        CreatedBy = dto.CreatedBy
    };

    db.Users.Add(user);
    await db.SaveChangesAsync();
    return Results.Ok(new { user.Id, user.Username, user.Role_Id, user.Pck_Id, user.CreatedBy });
});

app.MapPost("/pck", async (PCK item, AppDbContext db) => { db.PCKs.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });
app.MapPost("/positions", async (Position item, AppDbContext db) => { db.Positions.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });
app.MapPost("/degrees", async (Degree item, AppDbContext db) => { db.Degrees.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });
app.MapPost("/employments", async (Employment item, AppDbContext db) => { db.Employments.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });
app.MapPost("/specialties", async (Specialty item, AppDbContext db) => { db.Specialties.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });
app.MapPost("/curriculums", async (Curriculum item, AppDbContext db) => { db.Curriculums.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });
app.MapPost("/groups", async (Group item, AppDbContext db) => { db.Groups.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });
app.MapPost("/discipline-cycles", async (DisciplineCycle item, AppDbContext db) => { db.DisciplineCycles.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });
app.MapPost("/disciplines", async (Discipline item, AppDbContext db) => { db.Disciplines.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });
app.MapPost("/curriculum-load", async (CurriculumLoad item, AppDbContext db) => { db.CurriculumLoads.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });
app.MapPost("/teachers", async (TeacherDto dto, AppDbContext db) => {
    var teacher = new Teacher
    {
        User_Id = dto.User_Id,
        PCK_Id = dto.Pck_Id,
        Fio = EncryptFio(dto.Fio),
        Position_Id = dto.Position_Id,
        Degree_Id = dto.Degree_Id,
        Employment_Id = dto.Employment_Id,
        KN_Number = dto.KN_Number,
        Category = dto.Category,
        Has_Higher_Education = dto.Has_Higher_Education
    };
    db.Teachers.Add(teacher);
    await db.SaveChangesAsync();
    return Results.Ok(teacher);
});
app.MapPost("/academic-years", async (AcademicYear item, AppDbContext db) => { db.AcademicYears.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });
app.MapPost("/group-academic-years", async (GroupAcademicYear item, AppDbContext db) => { db.GroupAcademicYears.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });
app.MapPost("/actual-load", async (ActualLoad item, AppDbContext db) => { db.ActualLoads.Add(item); await db.SaveChangesAsync(); return Results.Ok(item); });

// ==================== PUT ОБНОВЛЕНИЕ ====================
app.MapPut("/roles/{id}", async (int id, Role input, AppDbContext db) => {
    var item = await db.Roles.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Role_Name = input.Role_Name;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/users/{id}", async (Guid id, UserUpdateDto input, AppDbContext db) => {
    var item = await db.Users.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Username = input.Username;
    item.Role_Id = input.Role_Id;
    item.Pck_Id = input.Pck_Id;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/users/{id}/password", async (Guid id, string newPassword, AppDbContext db) => {
    var item = await db.Users.FindAsync(id);
    if (item == null) return Results.NotFound();
    var (hash, salt) = await HashPassword(newPassword);
    item.PasswordHash = hash;
    item.Salt = salt;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/pck/{id}", async (int id, PCK input, AppDbContext db) => {
    var item = await db.PCKs.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Full_PCK_Name = input.Full_PCK_Name;
    item.Short_PCK_Name = input.Short_PCK_Name;
    item.Manager_Id = input.Manager_Id;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/positions/{id}", async (int id, Position input, AppDbContext db) => {
    var item = await db.Positions.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Position_Name = input.Position_Name;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/degrees/{id}", async (int id, Degree input, AppDbContext db) => {
    var item = await db.Degrees.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Degree_Name = input.Degree_Name;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/employments/{id}", async (int id, Employment input, AppDbContext db) => {
    var item = await db.Employments.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Employment_Name = input.Employment_Name;
    item.Format = input.Format;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/specialties/{id}", async (int id, Specialty input, AppDbContext db) => {
    var item = await db.Specialties.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Full_Name_Specialty = input.Full_Name_Specialty;
    item.Short_Name_Specialty = input.Short_Name_Specialty;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/curriculums/{id}", async (int id, Curriculum input, AppDbContext db) => {
    var item = await db.Curriculums.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Full_Name_UP = input.Full_Name_UP;
    item.Short_Name_UP = input.Short_Name_UP;
    item.Year_Approved = input.Year_Approved;
    item.Education_Form = input.Education_Form;
    item.Specialty_Id = input.Specialty_Id;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/groups/{id}", async (int id, Group input, AppDbContext db) => {
    var item = await db.Groups.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Group_Name = input.Group_Name;
    item.Id_UP = input.Id_UP;
    item.Admission_Year = input.Admission_Year;
    item.Education_Form = input.Education_Form;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/discipline-cycles/{id}", async (int id, DisciplineCycle input, AppDbContext db) => {
    var item = await db.DisciplineCycles.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Full_Cycle_Name = input.Full_Cycle_Name;
    item.Short_Cycle_Name = input.Short_Cycle_Name;
    item.Discipline_Group = input.Discipline_Group;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/disciplines/{id}", async (int id, Discipline input, AppDbContext db) => {
    var item = await db.Disciplines.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Full_Discipline_Name = input.Full_Discipline_Name;
    item.Short_Discipline_Name = input.Short_Discipline_Name;
    item.PCK_Id = input.PCK_Id;
    item.Cycle_Id = input.Cycle_Id;
    item.Practice_Type = input.Practice_Type;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/curriculum-load/{id}", async (int id, CurriculumLoad input, AppDbContext db) => {
    var item = await db.CurriculumLoads.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.UP_Id = input.UP_Id;
    item.Discipline_Id = input.Discipline_Id;
    item.Semester = input.Semester;
    item.Total_Hours = input.Total_Hours;
    item.Subgroup_Number = input.Subgroup_Number;
    item.Lectures = input.Lectures;
    item.Lab_Works = input.Lab_Works;
    item.Practice_Works = input.Practice_Works;
    item.Consultations = input.Consultations;
    item.Is_Credit = input.Is_Credit;
    item.Is_Diff_Credit = input.Is_Diff_Credit;
    item.Is_Exam = input.Is_Exam;
    item.Is_Complex_Exam = input.Is_Complex_Exam;
    item.Is_Control_Work = input.Is_Control_Work;
    item.Is_Course_Work = input.Is_Course_Work;
    item.Course_Work_Defense = input.Course_Work_Defense;
    item.Temp = input.Temp;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/teachers/{id}", async (int id, TeacherDto input, AppDbContext db) => {
    var item = await db.Teachers.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Fio = EncryptFio(input.Fio);
    item.PCK_Id = input.Pck_Id;
    item.Position_Id = input.Position_Id;
    item.Degree_Id = input.Degree_Id;
    item.Employment_Id = input.Employment_Id;
    item.KN_Number = input.KN_Number;
    item.Category = input.Category;
    item.Has_Higher_Education = input.Has_Higher_Education;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/academic-years/{id}", async (int id, AcademicYear input, AppDbContext db) => {
    var item = await db.AcademicYears.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Start_Year = input.Start_Year;
    item.Can_Edit = input.Can_Edit;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/group-academic-years/{id}", async (int id, GroupAcademicYear input, AppDbContext db) => {
    var item = await db.GroupAcademicYears.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Group_Id = input.Group_Id;
    item.AcademicYear_Id = input.AcademicYear_Id;
    item.Budget_Students = input.Budget_Students;
    item.Contract_Students = input.Contract_Students;
    item.First_Subgroup_Count = input.First_Subgroup_Count;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapPut("/actual-load/{id}", async (int id, ActualLoad input, AppDbContext db) => {
    var item = await db.ActualLoads.FindAsync(id);
    if (item == null) return Results.NotFound();
    item.Load_UP_Id = input.Load_UP_Id;
    item.Group_Id = input.Group_Id;
    item.Teacher_Id = input.Teacher_Id;
    item.Lectures = input.Lectures;
    item.Lab_Works = input.Lab_Works;
    item.Practice_Works = input.Practice_Works;
    item.Consultations = input.Consultations;
    item.Credit = input.Credit;
    item.Diff_Credit = input.Diff_Credit;
    item.Exam = input.Exam;
    item.Complex_Exam = input.Complex_Exam;
    item.Control_Work = input.Control_Work;
    item.Course_Work = input.Course_Work;
    item.Course_Work_Defense = input.Course_Work_Defense;
    item.Is_Approved = input.Is_Approved;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

// ==================== DELETE УДАЛЕНИЕ ====================
app.MapDelete("/{table}/{id}", async (string table, string id, AppDbContext db) => {
    switch (table.ToLower())
    {
        case "roles":
            var role = await db.Roles.FindAsync(int.Parse(id));
            if (role != null) db.Roles.Remove(role);
            break;
        case "users":
            var user = await db.Users.FindAsync(Guid.Parse(id));
            if (user != null) db.Users.Remove(user);
            break;
        case "groups":
            var group = await db.Groups.FindAsync(int.Parse(id));
            if (group != null) db.Groups.Remove(group);
            break;
        case "teachers":
            var teacher = await db.Teachers.FindAsync(int.Parse(id));
            if (teacher != null) db.Teachers.Remove(teacher);
            break;
        case "pck":
            var pck = await db.PCKs.FindAsync(int.Parse(id));
            if (pck != null) db.PCKs.Remove(pck);
            break;
        case "disciplines":
            var discipline = await db.Disciplines.FindAsync(int.Parse(id));
            if (discipline != null) db.Disciplines.Remove(discipline);
            break;
        case "specialties":
            var specialty = await db.Specialties.FindAsync(int.Parse(id));
            if (specialty != null) db.Specialties.Remove(specialty);
            break;
        case "curriculums":
            var curriculum = await db.Curriculums.FindAsync(int.Parse(id));
            if (curriculum != null) db.Curriculums.Remove(curriculum);
            break;
        case "positions":
            var position = await db.Positions.FindAsync(int.Parse(id));
            if (position != null) db.Positions.Remove(position);
            break;
        case "degrees":
            var degree = await db.Degrees.FindAsync(int.Parse(id));
            if (degree != null) db.Degrees.Remove(degree);
            break;
        case "employments":
            var employment = await db.Employments.FindAsync(int.Parse(id));
            if (employment != null) db.Employments.Remove(employment);
            break;
        case "discipline-cycles":
            var cycle = await db.DisciplineCycles.FindAsync(int.Parse(id));
            if (cycle != null) db.DisciplineCycles.Remove(cycle);
            break;
        case "curriculum-load":
            var load = await db.CurriculumLoads.FindAsync(int.Parse(id));
            if (load != null) db.CurriculumLoads.Remove(load);
            break;
        case "academic-years":
            var year = await db.AcademicYears.FindAsync(int.Parse(id));
            if (year != null) db.AcademicYears.Remove(year);
            break;
        case "group-academic-years":
            var groupYear = await db.GroupAcademicYears.FindAsync(int.Parse(id));
            if (groupYear != null) db.GroupAcademicYears.Remove(groupYear);
            break;
        case "actual-load":
            var actual = await db.ActualLoads.FindAsync(int.Parse(id));
            if (actual != null) db.ActualLoads.Remove(actual);
            break;
    }
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.Run();

// ==================== МОДЕЛИ ДАННЫХ ====================

[Table("Roles")]
public class Role
{
    [Key] public int Id_Role { get; set; }
    public string Role_Name { get; set; } = "";
}

[Table("Users")]
public class User
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public string Username { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string Salt { get; set; } = "";
    public int Role_Id { get; set; }
    public int? Pck_Id { get; set; }
    public Guid? CreatedBy { get; set; }
}

public class UserCreateDto
{
    public string Username { get; set; } = "";
    public string Password { get; set; } = "";
    public int Role_Id { get; set; }
    public int? Pck_Id { get; set; }
    public Guid? CreatedBy { get; set; }
}

public class UserUpdateDto
{
    public string Username { get; set; } = "";
    public int Role_Id { get; set; }
    public int? Pck_Id { get; set; }
}

[Table("PCK")]
public class PCK
{
    [Key] public int Id_PCK { get; set; }
    public string Full_PCK_Name { get; set; } = "";
    public string Short_PCK_Name { get; set; } = "";
    public Guid? Manager_Id { get; set; }
}

[Table("Positions")]
public class Position
{
    [Key] public int Id_Position { get; set; }
    public string Position_Name { get; set; } = "";
}

[Table("Degrees")]
public class Degree
{
    [Key] public int Id_Degree { get; set; }
    public string Degree_Name { get; set; } = "";
}

[Table("Employments")]
public class Employment
{
    [Key] public int Id_Employment { get; set; }
    public string Employment_Name { get; set; } = "";
    public string? Format { get; set; }
}

[Table("Specialties")]
public class Specialty
{
    [Key] public int Id_Specialty { get; set; }
    public string Full_Name_Specialty { get; set; } = "";
    public string? Short_Name_Specialty { get; set; }
}

[Table("Curriculums")]
public class Curriculum
{
    [Key] public int Id_UP { get; set; }
    public string? Short_Name_UP { get; set; }
    public string Full_Name_UP { get; set; } = "";
    public int? Year_Approved { get; set; }
    public string? Education_Form { get; set; }
    public int? Specialty_Id { get; set; }
}

[Table("Groups")]
public class Group
{
    [Key] public int Id_Group { get; set; }
    public string Group_Name { get; set; } = "";
    public int Id_UP { get; set; }
    public int? Admission_Year { get; set; }
    public string? Education_Form { get; set; }
}

[Table("DisciplineCycles")]
public class DisciplineCycle
{
    [Key] public int Id_Cycle { get; set; }
    public string Full_Cycle_Name { get; set; } = "";
    public string? Short_Cycle_Name { get; set; }
    public string? Discipline_Group { get; set; }
}

[Table("Disciplines")]
public class Discipline
{
    [Key] public int Id_Discipline { get; set; }
    public string Full_Discipline_Name { get; set; } = "";
    public string? Short_Discipline_Name { get; set; }
    public int PCK_Id { get; set; }
    public int? Cycle_Id { get; set; }
    public string? Practice_Type { get; set; }
}

[Table("CurriculumLoad")]
public class CurriculumLoad
{
    [Key] public int Id_Load { get; set; }
    public int UP_Id { get; set; }
    public int Discipline_Id { get; set; }
    public int Semester { get; set; }
    public int? Total_Hours { get; set; }
    public int? Subgroup_Number { get; set; }
    public int? Lectures { get; set; }
    public int? Lab_Works { get; set; }
    public int? Practice_Works { get; set; }
    public int? Consultations { get; set; }
    public bool? Is_Credit { get; set; }
    public bool? Is_Diff_Credit { get; set; }
    public bool? Is_Exam { get; set; }
    public bool? Is_Complex_Exam { get; set; }
    public bool? Is_Control_Work { get; set; }
    public bool? Is_Course_Work { get; set; }
    public int? Course_Work_Defense { get; set; }
    public int? Temp { get; set; }
}

[Table("Teachers")]
public class Teacher
{
    [Key] public int Id_Teacher { get; set; }
    public Guid User_Id { get; set; }
    public byte[] Fio { get; set; } = Array.Empty<byte>();
    public int? KN_Number { get; set; }
    public string? Category { get; set; }
    public int? Degree_Id { get; set; }
    public int? Position_Id { get; set; }
    public int? Employment_Id { get; set; }
    public int PCK_Id { get; set; }
    public bool? Has_Higher_Education { get; set; }
}

[Table("AcademicYears")]
public class AcademicYear
{
    [Key] public int Id_AcademicYear { get; set; }
    public int Start_Year { get; set; }
    public bool? Can_Edit { get; set; }
}

[Table("Group_AcademicYears")]
public class GroupAcademicYear
{
    [Key] public int Id_Group_AcademicYear { get; set; }
    public int Group_Id { get; set; }
    public int AcademicYear_Id { get; set; }
    public int? Budget_Students { get; set; }
    public int? Contract_Students { get; set; }
    public int? First_Subgroup_Count { get; set; }
}

[Table("ActualLoad")]
public class ActualLoad
{
    [Key] public int Id_ActualLoad { get; set; }
    public int Load_UP_Id { get; set; }
    public int Group_Id { get; set; }
    public int Teacher_Id { get; set; }
    public decimal? Lectures { get; set; }
    public decimal? Lab_Works { get; set; }
    public decimal? Practice_Works { get; set; }
    public decimal? Consultations { get; set; }
    public decimal? Credit { get; set; }
    public decimal? Diff_Credit { get; set; }
    public decimal? Exam { get; set; }
    public decimal? Complex_Exam { get; set; }
    public decimal? Control_Work { get; set; }
    public decimal? Course_Work { get; set; }
    public decimal? Course_Work_Defense { get; set; }
    public bool? Is_Approved { get; set; }
}

public class TeacherDto
{
    public Guid User_Id { get; set; }
    public string Fio { get; set; } = "";
    public int Pck_Id { get; set; }
    public int? Position_Id { get; set; }
    public int? Degree_Id { get; set; }
    public int? Employment_Id { get; set; }
    public int? KN_Number { get; set; }
    public string? Category { get; set; }
    public bool? Has_Higher_Education { get; set; }
}

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<User> Users => Set<User>();
    public DbSet<PCK> PCKs => Set<PCK>();
    public DbSet<Position> Positions => Set<Position>();
    public DbSet<Degree> Degrees => Set<Degree>();
    public DbSet<Employment> Employments => Set<Employment>();
    public DbSet<Specialty> Specialties => Set<Specialty>();
    public DbSet<Curriculum> Curriculums => Set<Curriculum>();
    public DbSet<Group> Groups => Set<Group>();
    public DbSet<DisciplineCycle> DisciplineCycles => Set<DisciplineCycle>();
    public DbSet<Discipline> Disciplines => Set<Discipline>();
    public DbSet<CurriculumLoad> CurriculumLoads => Set<CurriculumLoad>();
    public DbSet<Teacher> Teachers => Set<Teacher>();
    public DbSet<AcademicYear> AcademicYears => Set<AcademicYear>();
    public DbSet<GroupAcademicYear> GroupAcademicYears => Set<GroupAcademicYear>();
    public DbSet<ActualLoad> ActualLoads => Set<ActualLoad>();
}