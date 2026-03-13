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

    let rows = sqlx::query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'subjects'")
        .fetch_all(&pool)
        .await?;

    println!("Table: subjects");
    for row in rows {
        let name: String = row.get("column_name");
        let dtype: String = row.get("data_type");
        println!("- {}: {}", name, dtype);
    }

    Ok(())
}
