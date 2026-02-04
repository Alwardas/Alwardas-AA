
use sqlx::postgres::PgPoolOptions;
use dotenvy::dotenv;
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await?;

    println!("Connected to database. Seeding users...");

    let users = vec![
        ("Student Demo", "Student", "student", "123", Some("CSE"), Some("2024")),
        ("Faculty Demo", "Faculty", "faculty", "123", Some("CSE"), None),
        ("HOD Demo", "HOD", "hod", "123", Some("CSE"), None),
        ("Principal Demo", "Principal", "principal", "123", None, None),
        ("Coordinator Demo", "Coordinator", "coordinator", "123", None, None),
        ("Admin Demo", "Admin", "admin", "123", None, None),
    ];

    for (name, role, login, pass, branch, year) in users {
        let result = sqlx::query(
            "INSERT INTO users (full_name, role, login_id, password_hash, branch, year, is_approved, dob) 
             VALUES ($1, $2, $3, $4, $5, $6, true, '2000-01-01')
             ON CONFLICT (login_id) DO UPDATE 
             SET is_approved = true, password_hash = $4"
        )
        .bind(name)
        .bind(role)
        .bind(login)
        .bind(pass)
        .bind(branch)
        .bind(year)
        .execute(&pool)
        .await;

        match result {
            Ok(_) => println!("Seeded user: {} ({})", login, role),
            Err(e) => println!("Failed to seed {}: {:?}", login, e),
        }
    }

    println!("Seeding complete!");
    Ok(())
}
