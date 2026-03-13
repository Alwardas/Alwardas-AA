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

    println!("Checking branches in subjects table:");
    let rows = sqlx::query("SELECT DISTINCT branch FROM subjects")
        .fetch_all(&pool)
        .await?;

    for row in rows {
        let b: String = row.get("branch");
        println!("- {}", b);
    }

    Ok(())
}
