using Microsoft.EntityFrameworkCore;
using Konscious.Security.Cryptography;
using System.Text;
using System.Security.Cryptography;
using System.ComponentModel.DataAnnotations.Schema;

var builder = WebApplication.CreateBuilder(args);

// Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Подключение к PostgreSQL
builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();

// --- СЕРВИС ШИФРОВАНИЯ ФИО (AES-256) ---
// В реальном проекте ключ должен быть в User Secrets или Key Vault!
byte[] key = Encoding.UTF8.GetBytes("A67890B234567890C1234567890D1234"); // 32 байта

byte[] EncryptFio(string text)
{
    using var aes = Aes.Create();
    aes.Key = key;
    aes.GenerateIV();
    using var encryptor = aes.CreateEncryptor();
    var plainBytes = Encoding.UTF8.GetBytes(text);
    var encrypted = encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);
    return aes.IV.Concat(encrypted).ToArray(); // Сохраняем IV вместе с данными
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

// --- API: РЕГИСТРАЦИЯ ---
app.MapPost("/register", async (string username, string password, int roleId, AppDbContext db) => {
    if (await db.Users.AnyAsync(x => x.Username == username)) return Results.BadRequest("Логин занят");

    var salt = RandomNumberGenerator.GetBytes(16);
    var argon2 = new Argon2id(Encoding.UTF8.GetBytes(password))
    {
        Salt = salt,
        DegreeOfParallelism = 4,
        Iterations = 2,
        MemorySize = 1024
    };
    var hash = await argon2.GetBytesAsync(16);

    var user = new User
    {
        Username = username,
        PasswordHash = Convert.ToBase64String(hash),
        Salt = Convert.ToBase64String(salt),
        Role_Id = roleId
    };

    db.Users.Add(user);
    await db.SaveChangesAsync();
    return Results.Ok(new { user.Id, message = "Пользователь создан" });
});

// --- API: ВХОД ---
app.MapPost("/login", async (string username, string password, AppDbContext db) => {
    var u = await db.Users.FirstOrDefaultAsync(x => x.Username == username);
    if (u == null) return Results.Unauthorized();

    var argon2 = new Argon2id(Encoding.UTF8.GetBytes(password))
    {
        Salt = Convert.FromBase64String(u.Salt),
        DegreeOfParallelism = 4,
        Iterations = 2,
        MemorySize = 1024
    };
    var isOk = Convert.ToBase64String(await argon2.GetBytesAsync(16)) == u.PasswordHash;
    return isOk ? Results.Ok(new { u.Id, u.Role_Id, u.Pck_Id }) : Results.Unauthorized();
});

// --- API: УЧИТЕЛЯ ---
app.MapPost("/teachers", async (Guid userId, int pckId, string fio, AppDbContext db) => {
    var teacher = new Teacher
    {
        User_Id = userId,
        Pck_Id = pckId,
        Fio = EncryptFio(fio) // Шифруем перед сохранением
    };
    db.Teachers.Add(teacher);
    await db.SaveChangesAsync();
    return Results.Ok("Учитель добавлен");
});

app.MapGet("/teachers", async (AppDbContext db) => {
    var list = await db.Teachers.ToListAsync();
    return list.Select(t => new {
        t.Id_Teacher,
        Fio = DecryptFio(t.Fio), // Расшифровка на лету
        t.Pck_Id
    });
});

app.Run();

// --- МОДЕЛИ ДАННЫХ (соответствуют твоей БД в Postgres) ---
[Table("Users")]
public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Username { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string Salt { get; set; } = "";
    public int Role_Id { get; set; }
    public int? Pck_Id { get; set; }
    public Guid? CreatedBy { get; set; }
}

[Table("Teachers")]
public class Teacher
{
    public int Id_Teacher { get; set; }
    public Guid User_Id { get; set; }
    public byte[] Fio { get; set; } = Array.Empty<byte>();
    public int Pck_Id { get; set; }
}

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
    public DbSet<User> Users => Set<User>();
    public DbSet<Teacher> Teachers => Set<Teacher>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Настройка ключей (для UUID и автоматических полей)
        modelBuilder.Entity<User>().HasKey(u => u.Id);
        modelBuilder.Entity<Teacher>().HasKey(t => t.Id_Teacher);

        // Регистрозависимые имена полей, если Postgres требует кавычек
        modelBuilder.Entity<User>().Property(u => u.Id).HasColumnName("Id");
        modelBuilder.Entity<Teacher>().Property(t => t.Id_Teacher).HasColumnName("Id_Teacher");
    }
}
