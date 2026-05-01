use tonic::{Request, Response, Status};
use crate::auth_proto::auth_service_server::AuthService;
use crate::auth_proto::{LoginRequest, LoginResponse, SignupRequest, SignupResponse, UserProfile};
use uuid::Uuid;
use crate::repositories::auth;

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

        // Use repository
        let user_result = auth::find_user_by_login_id(&self.pool, &login_id)
            .await
            .map_err(|e| Status::internal(format!("DB Error: {}", e)))?;

        if let Some(user) = user_result {
            if user.password_hash.trim() == password.trim() {
                if !user.is_approved.unwrap_or(false) {
                     return Ok(Response::new(LoginResponse {
                        success: false,
                        message: "Account pending approval".to_string(),
                        token: "".to_string(),
                        user_id: "".to_string(),
                        user_profile: None,
                    }));
                }

                return Ok(Response::new(LoginResponse {
                    success: true,
                    message: "Login Successful".to_string(),
                    token: "dummy-token".to_string(), 
                    user_id: user.id.to_string(),
                    user_profile: Some(UserProfile {
                        name: user.full_name,
                        role: user.role,
                        branch: user.branch.unwrap_or_default(),
                        year: user.year.unwrap_or_default(),
                        semester: user.semester.unwrap_or_default(),
                        batch_no: user.batch_no.unwrap_or_default(),
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
        
        let exists = auth::find_user_id_by_login_id(&self.pool, &req.login_id)
            .await
            .map_err(|e| Status::internal(format!("DB Error: {}", e)))?;

        if exists.is_some() {
             return Ok(Response::new(SignupResponse {
                success: false,
                message: "User already exists".to_string(),
                user_id: "".to_string(),
            }));
        }

        // Simplified insert for gRPC (could be expanded to use a shared helper)
        let row = sqlx::query(
            "INSERT INTO users (full_name, login_id, password_hash, branch, year, role, is_approved) 
             VALUES ($1, $2, $3, $4, $5, 'Student', FALSE) RETURNING id"
        )
        .bind(&req.full_name)
        .bind(&req.login_id)
        .bind(&req.password)
        .bind(&req.branch)
        .bind(&req.year)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| Status::internal(format!("Signup Failed: {}", e)))?;

        use sqlx::Row;
        let uid: Uuid = row.get("id");

        Ok(Response::new(SignupResponse {
            success: true,
            message: "Signup Successful (Pending Approval)".to_string(),
            user_id: uid.to_string(),
        }))
    }
}
