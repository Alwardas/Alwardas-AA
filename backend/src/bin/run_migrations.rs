use sqlx::{postgres::PgPoolOptions};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();
    let url = std::env::var("DATABASE_URL")?;
    let pool = PgPoolOptions::new().connect(&url).await?;

    println!("Running migrations...");
    match sqlx::migrate!("./migrations").run(&pool).await {
        Ok(_) => println!("✅ Migrations complete!"),
        Err(e) => {
            eprintln!("❌ Migration error: {:?}", e);
        }
    }
    Ok(())
}
