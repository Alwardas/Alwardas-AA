use sqlx::{postgres::PgPoolOptions, Row};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();
    let url = std::env::var("DATABASE_URL")?;
    let pool = PgPoolOptions::new().connect(&url).await?;

    let rows = sqlx::query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
        .fetch_all(&pool)
        .await?;

    println!("--- SUPABASE TABLES ---");
    for row in rows {
        let table_name: String = row.get("table_name");
        println!(" - {}", table_name);
    }
    println!("-----------------------");
    Ok(())
}
