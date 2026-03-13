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

    println!("Checking users with role = 'HOD':");
    let rows = sqlx::query("SELECT full_name, branch, role FROM users WHERE role = 'HOD'")
        .fetch_all(&pool)
        .await?;

    for row in rows {
        let name: String = row.get("full_name");
        let branch: Option<String> = row.get("branch");
        let role: String = row.get("role");
        println!("Name: {}, Branch: {:?}, Role: {}", name, branch, role);
    }

    Ok(())
}
