
use sqlx::postgres::PgPoolOptions;
use dotenvy::dotenv;
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let pool = PgPoolOptions::new().connect(&database_url).await?;

    let rows: Vec<(String, String)> = sqlx::query_as("SELECT DISTINCT branch, semester FROM subjects")
        .fetch_all(&pool)
        .await?;

    println!("Current branches and semesters in subjects table:");
    for (branch, semester) in rows {
        println!("Branch: '{}', Semester: '{}'", branch, semester);
    }

    Ok(())
}
