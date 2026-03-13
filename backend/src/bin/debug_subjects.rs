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

    let branch = "Computer Engineering";
    println!("Checking subjects for branch: {}", branch);
    let rows = sqlx::query("SELECT name, semester FROM subjects WHERE branch = $1")
        .bind(branch)
        .fetch_all(&pool)
        .await?;

    for row in rows {
        let name: String = row.get("name");
        let sem: String = row.get("semester");
        println!("Subject: {}, Semester: {}", name, sem);
    }

    Ok(())
}
