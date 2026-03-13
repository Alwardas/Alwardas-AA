use sqlx::{postgres::PgPoolOptions, Row};
use dotenvy::dotenv;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    let database_url = std::env::var("DATABASE_URL")?;
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await?;

    println!("Checking all subjects and their semesters:");
    let rows = sqlx::query("SELECT name, branch, semester FROM subjects LIMIT 50")
        .fetch_all(&pool)
        .await?;

    for row in rows {
        let name: String = row.get("name");
        let branch: String = row.get("branch");
        let sem: String = row.get("semester");
        println!("Subject: {}, Branch: {}, Semester: {}", name, branch, sem);
    }

    Ok(())
}
