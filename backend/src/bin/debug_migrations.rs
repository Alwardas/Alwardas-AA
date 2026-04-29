use sqlx::{postgres::PgPoolOptions};
use std::fs;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();
    let url = std::env::var("DATABASE_URL")?;
    let pool = PgPoolOptions::new().connect(&url).await?;

    let mut paths: Vec<_> = fs::read_dir("./migrations")?
        .filter_map(Result::ok)
        .map(|e| e.path())
        .filter(|p| p.extension().and_then(|s| s.to_str()) == Some("sql"))
        .collect();
    
    paths.sort();

    for path in paths {
        let filename = path.file_name().unwrap().to_str().unwrap();
        println!("Running {}...", filename);
        let sql = fs::read_to_string(&path)?;
        
        match sqlx::query(&sql).execute(&pool).await {
            Ok(_) => println!("✅ Success: {}", filename),
            Err(e) => {
                eprintln!("❌ Failed: {}. Error: {:?}", filename, e);
                break;
            }
        }
    }
    Ok(())
}
