use tonic::{Request, Response, Status};
use crate::auth_proto::auth_service_server::AuthService;
use crate::auth_proto::{LoginRequest, LoginResponse, SignupRequest, SignupResponse, UserProfile};
use sqlx::Row;
use uuid::Uuid;

pub struct MyAuthService {
    pub pool: sqlx::PgPool,
}

#[tonic::async_trait]
impl AuthService for MyAuthService {
    async fn login(
        &self,
        request: Request<LoginRequest>,
    ) -> Result<Response<LoginResponse>, Status> {
        let req = request.into_inner();
        let login_id = req.login_id;
        let password = req.password;

        // Fetch user
        let user = sqlx::query("SELECT id, full_name, role, password_hash, is_approved, branch, year, semester, batch_no FROM users WHERE login_id = $1")
            .bind(&login_id)
            .fetch_optional(&self.pool)
            .await
            .map_err(|e| Status::internal(format!("DB Error: {}", e)))?;

        if let Some(row) = user {
            let password_hash: String = row.get("password_hash");
            let is_approved: bool = row.get::<Option<bool>, _>("is_approved").unwrap_or(false);
            
            if password_hash == password {
                if !is_approved {
                     return Ok(Response::new(LoginResponse {
                        success: false,
                        message: "Account pending approval".to_string(),
                        token: "".to_string(),
                        user_id: "".to_string(),
                        user_profile: None,
                    }));
                }

                let uid: Uuid = row.get("id");
                let full_name: String = row.get("full_name");
                let role: String = row.get("role");
                let branch: Option<String> = row.get("branch");
                let year: Option<String> = row.get("year");
                let semester: Option<String> = row.get("semester");
                let batch_no: Option<String> = row.get("batch_no");

                return Ok(Response::new(LoginResponse {
                    success: true,
                    message: "Login Successful".to_string(),
                    token: "dummy-token".to_string(), 
                    user_id: uid.to_string(),
                    user_profile: Some(UserProfile {
                        name: full_name,
                        role: role,
                        branch: branch.unwrap_or_default(),
                        year: year.unwrap_or_default(),
                        semester: semester.unwrap_or_default(),
                        batch_no: batch_no.unwrap_or_default(),
                        login_id: login_id.clone(),
                    }),
                }));
            }
        }

        Ok(Response::new(LoginResponse {
            success: false,
            message: "Invalid ID or Password".to_string(),
            token: "".to_string(),
            user_id: "".to_string(),
            user_profile: None,
        }))
    }

    async fn signup(
        &self,
        request: Request<SignupRequest>,
    ) -> Result<Response<SignupResponse>, Status> {
        let req = request.into_inner();
        
        // Basic implementation mirroring existing logic
        // For brevity, assuming simple student/faculty logic or reusing helper functions if refactored
        // Implementing basic insertion:
        
        let is_approved = false; // Default logic
        
        // Check existence
        let exists = sqlx::query("SELECT id FROM users WHERE login_id = $1")
            .bind(&req.login_id)
            .fetch_optional(&self.pool)
            .await
            .map_err(|e| Status::internal(format!("DB Error: {}", e)))?;

        if exists.is_some() {
             return Ok(Response::new(SignupResponse {
                success: false,
                message: "User already exists".to_string(),
                user_id: "".to_string(),
            }));
        }

        // Insert (Simplified for migration proof-of-concept)
        // Note: Real implementation needs all the column logic from main.rs
        let row = sqlx::query(
            "INSERT INTO users (full_name, login_id, password_hash, branch, year, role, is_approved) 
             VALUES ($1, $2, $3, $4, $5, 'Student', $6) RETURNING id"
        )
        .bind(&req.full_name)
        .bind(&req.login_id)
        .bind(&req.password)
        .bind(&req.branch)
        .bind(&req.year)
        .bind(is_approved)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| Status::internal(format!("Signup Failed: {}", e)))?;

        let uid: Uuid = row.get("id");

        Ok(Response::new(SignupResponse {
            success: true,
            message: "Signup Successful (Pending Approval)".to_string(),
            user_id: uid.to_string(),
        }))
    }
}
