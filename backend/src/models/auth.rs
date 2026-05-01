use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct SignupRequest {
    pub full_name: String,
    pub role: String,
    pub login_id: String,       // Maps to studentId, facultyId, etc. from frontend
    pub password: String,
    pub branch: Option<String>,
    pub year: Option<String>,
    pub section: Option<String>,
    pub phone_number: Option<String>,
    pub dob: Option<String>, // "YYYY-MM-DD"
    pub experience: Option<String>,
    pub email: Option<String>,
    pub semester: Option<String>,
    pub batch_no: Option<String>,
    pub title: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct LoginRequest {
    pub login_id: String,
    pub password: String,
}

#[derive(Serialize, Debug)]
pub struct AuthResponse {
    pub id: Option<String>,
    pub message: String,
    pub role: Option<String>,
    pub full_name: Option<String>,
    pub login_id: Option<String>,
    pub branch: Option<String>,
    pub year: Option<String>,
    pub semester: Option<String>,
    pub batch_no: Option<String>,
    pub section: Option<String>,
}
