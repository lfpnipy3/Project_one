using Microsoft.EntityFrameworkCore;
using Konscious.Security.Cryptography;
using System.Text;
using System.Security.Cryptography;

var builder = WebApplication.CreateBuilder(args);

// --- ДОБАВЛЕНО ДЛЯ SWAGGER ---
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

var app = builder.Build();

// --- ДОБАВЛЕНО ДЛЯ SWAGGER ---
app.UseSwagger();
app.UseSwaggerUI();

// --- АВТОРИЗАЦИЯ ---
app.MapPost("/register", async (string username, string password, AppDbContext db) => {
    var salt = RandomNumberGenerator.GetBytes(16);
    var argon2 = new Argon2id(Encoding.UTF8.GetBytes(password))
    {
        Salt = salt,
        DegreeOfParallelism = 4,
        Iterations = 2,
        MemorySize = 1024
    };
    var hash = await argon2.GetBytesAsync(16);
    db.Users.Add(new User { Username = username, PasswordHash = Convert.ToBase64String(hash), Salt = Convert.ToBase64String(salt) });
    await db.SaveChangesAsync();
    return Results.Ok("Создан");
});

app.MapPost("/login", async (string username, string password, AppDbContext db) => {
    var u = await db.Users.FirstOrDefaultAsync(x => x.Username == username);
    if (u == null) return Results.BadRequest("Нет юзера");
    var argon2 = new Argon2id(Encoding.UTF8.GetBytes(password))
    {
        Salt = Convert.FromBase64String(u.Salt),
        DegreeOfParallelism = 4,
        Iterations = 2,
        MemorySize = 1024
    };
    return Convert.ToBase64String(await argon2.GetBytesAsync(16)) == u.PasswordHash ? Results.Ok("OK") : Results.BadRequest("Fail");
});

// --- СОТРУДНИКИ ---
app.MapGet("/employees", async (AppDbContext db) => await db.Employees.ToListAsync());

app.MapDelete("/employees/{id}", async (int id, AppDbContext db) => {
    var emp = await db.Employees.FindAsync(id);
    if (emp == null) return Results.NotFound();
    db.Employees.Remove(emp);
    await db.SaveChangesAsync();
    return Results.Ok();
});

app.Run();

// --- МОДЕЛИ --- (оставляем без изменений)
public class User { public int Id { get; set; } public string Username { get; set; } = ""; public string PasswordHash { get; set; } = ""; public string Salt { get; set; } = ""; }
public class Employee { public int Id { get; set; } public string Name { get; set; } = ""; public string Role { get; set; } = ""; public string Status { get; set; } = ""; }
public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
    public DbSet<User> Users => Set<User>();
    public DbSet<Employee> Employees => Set<Employee>();
}
