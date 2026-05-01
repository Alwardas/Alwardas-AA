use sqlx::{PgPool};
use axum::http::StatusCode;
use uuid::Uuid;
use crate::models::{
    ParentProfileResponse, SubmitParentRequest, ParentRequest,
    ParentRequestQuery
};
use crate::utils::user_utils::resolve_user_id;
use crate::repositories::user::parent_repository;

pub async fn get_parent_profile(pool: &PgPool, user_id: &str) -> Result<ParentProfileResponse, StatusCode> {
    let user_uuid = resolve_user_id(user_id, "Parent", pool).await.map_err(|_| StatusCode::BAD_REQUEST)?;

    let (full_name, login_id, phone_number, email) = parent_repository::find_parent_basics_by_id(pool, user_uuid)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    let student_opt = parent_repository::find_student_by_parent_login(pool, &login_id).await.unwrap_or(None);

    let final_student_opt = if student_opt.is_none() {
        let legacy_id = if login_id.starts_with("P-") { login_id[2..].to_string() } else { login_id.clone() };
        parent_repository::find_student_by_login_id(pool, &legacy_id).await.unwrap_or(None)
    } else {
        student_opt
    };

    Ok(ParentProfileResponse { full_name, phone_number, email, student: final_student_opt })
}

pub async fn submit_parent_request(pool: &PgPool, payload: SubmitParentRequest) -> Result<(), StatusCode> {
    let parent_uuid = Uuid::parse_str(&payload.parent_id).map_err(|_| StatusCode::BAD_REQUEST)?;
    let student_uuid = Uuid::parse_str(&payload.student_id).map_err(|_| StatusCode::BAD_REQUEST)?;

    let student_branch = parent_repository::get_user_branch_by_id(pool, student_uuid).await.unwrap_or(None);
    let mut target_uuids = std::collections::HashSet::new();

    if let Some(fac_ids) = &payload.target_faculty_ids {
        for f_id in fac_ids { if let Ok(u) = Uuid::parse_str(f_id) { target_uuids.insert(u); } }
    }

    if let Some(roles) = &payload.target_roles {
        for role in roles {
            match role.as_str() {
                "HOD" => if let Some(ref branch) = student_branch {
                    if let Some(id) = parent_repository::find_hod_id_by_branch(pool, branch).await.unwrap_or(None) { target_uuids.insert(id); }
                },
                "Coordinator" => if let Some(ref branch) = student_branch {
                    if let Some(id) = parent_repository::find_coordinator_id_by_branch(pool, branch).await.unwrap_or(None) { target_uuids.insert(id); }
                },
                "Principal" => {
                    if let Some(id) = parent_repository::find_principal_id(pool).await.unwrap_or(None) { target_uuids.insert(id); }
                },
                _ => {}
            }
        }
    }

    if target_uuids.is_empty() {
        parent_repository::insert_parent_request(pool, parent_uuid, student_uuid, &payload.request_type, &payload.subject, &payload.description, &payload.date_duration, None, payload.voice_note.as_deref())
            .await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    } else {
        for assigned_to in target_uuids {
            parent_repository::insert_parent_request(pool, parent_uuid, student_uuid, &payload.request_type, &payload.subject, &payload.description, &payload.date_duration, Some(assigned_to), payload.voice_note.as_deref())
                .await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        }
    }
    Ok(())
}

pub async fn get_parent_requests(pool: &PgPool, params: ParentRequestQuery) -> Result<Vec<ParentRequest>, StatusCode> {
    parent_repository::find_parent_requests(pool, params)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn update_parent_request_status(pool: &PgPool, request_id: Uuid, status: String) -> Result<(), StatusCode> {
    parent_repository::update_parent_request_status(pool, request_id, &status)
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn delete_parent_request(pool: &PgPool, request_id: Uuid) -> Result<(), StatusCode> {
    parent_repository::delete_parent_request(pool, request_id)
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}
