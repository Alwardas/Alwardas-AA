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

    println!("Checking sections table:");
    let rows = sqlx::query("SELECT branch, year, section_name FROM sections")
        .fetch_all(&pool)
        .await?;

    for row in rows {
        let b: String = row.get("branch");
        let y: String = row.get("year");
        let s: String = row.get("section_name");
        println!("Branch: {}, Year: {}, Section: {}", b, y, s);
    }

    Ok(())
}
