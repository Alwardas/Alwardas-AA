use sqlx::{postgres::PgPoolOptions, Row};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();
    let url = std::env::var("DATABASE_URL")?;
    let pool = PgPoolOptions::new().connect(&url).await?;

    println!("Fetching _sqlx_migrations table...");
    let rows = sqlx::query("SELECT version, description, success FROM _sqlx_migrations ORDER BY version")
        .fetch_all(&pool)
        .await?;

    for row in rows {
        let version: i64 = row.get("version");
        let description: String = row.get("description");
        let success: bool = row.get("success");
        println!("Version: {}, Description: {}, Success: {}", version, description, success);
    }

    Ok(())
}
