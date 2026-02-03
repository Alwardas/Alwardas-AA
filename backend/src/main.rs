use axum::{
    routing::{get, post},
    Router,
    http::Method,
};
use sqlx::{postgres::{PgPoolOptions, PgConnectOptions}, Pool, Postgres};
use tower_http::cors::{Any, CorsLayer};
use dotenvy::dotenv;
use std::str::FromStr;

pub mod auth_proto {
    tonic::include_proto!("auth");
}

mod services;
use services::auth::MyAuthService;
use auth_proto::auth_service_server::AuthServiceServer;

mod models;
use models::AppState;

mod routes;
use routes::*;

use tower::Service;
use axum::extract::Request;
use axum::body::Body;

#[tokio::main]
async fn main() {
    println!("DEBUG: Starting application...");
    let port_str = std::env::var("PORT").unwrap_or_else(|_| "3001".to_string());
    println!("DEBUG: PORT env var is: '{}'", port_str);
    
    // Slight delay to ensure logs are flushed if the container crashes
    tokio::time::sleep(std::time::Duration::from_millis(500)).await;

    let port = port_str.parse::<u16>().expect("Invalid PORT env var");
    // Parse the address more robustly
    let addr = std::net::SocketAddr::from(([0, 0, 0, 0], port));

    println!("🚀 Server listening on {}", addr);
    
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    loop {
        let (mut socket, _) = listener.accept().await.unwrap();
        tokio::spawn(async move {
            use tokio::io::AsyncWriteExt;
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 12\r\n\r\nHello World!";
            if let Err(e) = socket.write_all(response.as_bytes()).await {
                eprintln!("failed to write to socket; err = {:?}", e);
            }
        });
    }
}

async fn root() -> &'static str {
    "Alwardas Backend Running!"
}

async fn fix_branch_names(pool: &Pool<Postgres>) {
    println!("DEBUG: Running fix_branch_names migration...");
    
    let updates = vec![
        ("CME", "Computer Engineering"),
        ("CM", "Computer Engineering"),
        ("Cme", "Computer Engineering"),
        ("Computer", "Computer Engineering"),
        ("ECE", "Electronics & Communication Engineering"),
        ("EC", "Electronics & Communication Engineering"),
        ("Ece", "Electronics & Communication Engineering"),
        ("EEE", "Electrical & Electronics Engineering"),
        ("EE", "Electrical & Electronics Engineering"),
        ("Eee", "Electrical & Electronics Engineering"),
        ("ME", "Mechanical Engineering"),
        ("MEC", "Mechanical Engineering"),
        ("MECH", "Mechanical Engineering"),
        ("Mech", "Mechanical Engineering"),
        ("Mechanical", "Mechanical Engineering"), 
        ("CE", "Civil Engineering"),
        ("CIV", "Civil Engineering"),
        ("CIVIL", "Civil Engineering"),
        ("Civil", "Civil Engineering"),
        ("BS & H", "General"),
        ("BS&H", "General"),
        ("BSH", "General"),
        ("Basic Science", "General"),
        ("General", "General"),
    ];

    let tables = vec!["users", "attendance", "notifications", "subjects", "faculty_subjects"];

    for (short_code, full_name) in updates {
        for table in &tables {
            let query = format!("UPDATE {} SET branch = $1 WHERE branch = $2", table);
            
            let result = sqlx::query(&query)
                .bind(full_name)
                .bind(short_code)
                .execute(pool)
                .await;
                
            match result {
                Ok(r) => {
                    if r.rows_affected() > 0 {
                        println!("Updated {} rows in '{}': {} -> {}", r.rows_affected(), table, short_code, full_name);
                    }
                },
                Err(e) => eprintln!("Failed to update table '{}': {:?}", table, e),
            }
        }
    }
}
