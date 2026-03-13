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
    println!("Subjects for branch: {}", branch);
    let rows = sqlx::query("SELECT name, semester FROM subjects WHERE branch = $1")
        .bind(branch)
        .fetch_all(&pool)
        .await?;

    if rows.is_empty() {
        println!("No subjects found for this branch.");
        // Try variations
        let variations = vec!["CME", "CM", "Cme", "Computer"];
        for v in variations {
             let r = sqlx::query("SELECT COUNT(*) FROM subjects WHERE branch = $1").bind(v).fetch_one(&pool).await?;
             let count: i64 = r.get(0);
             println!("Variation {}: {} subjects", v, count);
        }
    } else {
        for row in rows {
            let name: String = row.get("name");
            let sem: String = row.get("semester");
            println!("- {} ({})", name, sem);
        }
    }

    Ok(())
}
