use sqlx::{PgPool};
use axum::http::StatusCode;
use crate::models::{Issue, IssueComment, SubmitIssueRequest, GetIssuesQuery, SubmitCommentRequest, AssignIssueRequest, UpdateIssueStatusRequest};
use uuid::Uuid;
use crate::repositories::common::issue_repository;

pub async fn submit_issue(
    pool: &PgPool,
    payload: SubmitIssueRequest,
) -> Result<(), (StatusCode, String)> {
    let created_by = Uuid::parse_str(&payload.created_by).map_err(|_| (StatusCode::BAD_REQUEST, "Invalid User ID".to_string()))?;

    issue_repository::insert_issue(pool, &payload.title, &payload.description, &payload.category, &payload.priority, created_by, &payload.user_role)
        .await
        .map_err(|e| {
            eprintln!("Submit Issue Error: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to submit issue: {}", e))
        })?;

    Ok(())
}

pub async fn get_issues(
    pool: &PgPool,
    params: GetIssuesQuery,
) -> Result<Vec<Issue>, (StatusCode, String)> {
    let user_uuid = Uuid::parse_str(&params.user_id).map_err(|_| (StatusCode::BAD_REQUEST, "Invalid User ID".to_string()))?;

    issue_repository::find_issues(pool, params, user_uuid)
        .await
        .map_err(|e| {
            eprintln!("Get Issues Error: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))
        })
}

pub async fn get_issue_details(
    pool: &PgPool,
    issue_id: Uuid,
) -> Result<Issue, (StatusCode, String)> {
    issue_repository::find_issue_by_id(pool, issue_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "Issue not found".to_string()))
}

pub async fn get_issue_comments(
    pool: &PgPool,
    issue_id: Uuid,
) -> Result<Vec<IssueComment>, (StatusCode, String)> {
    issue_repository::find_issue_comments(pool, issue_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))
}

pub async fn submit_comment(
    pool: &PgPool,
    payload: SubmitCommentRequest,
) -> Result<(), (StatusCode, String)> {
    let issue_id = Uuid::parse_str(&payload.issue_id).map_err(|_| (StatusCode::BAD_REQUEST, "Invalid Issue ID".to_string()))?;
    let comment_by = Uuid::parse_str(&payload.comment_by).map_err(|_| (StatusCode::BAD_REQUEST, "Invalid User ID".to_string()))?;

    issue_repository::insert_comment(pool, issue_id, &payload.comment, comment_by)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(())
}

pub async fn assign_issue(
    pool: &PgPool,
    issue_id: Uuid,
    payload: AssignIssueRequest,
) -> Result<(), (StatusCode, String)> {
    let assigned_to = Uuid::parse_str(&payload.assigned_to).map_err(|_| (StatusCode::BAD_REQUEST, "Invalid User ID".to_string()))?;

    issue_repository::update_issue_assignment(pool, issue_id, assigned_to)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(())
}

pub async fn update_issue_status(
    pool: &PgPool,
    issue_id: Uuid,
    payload: UpdateIssueStatusRequest,
) -> Result<(), (StatusCode, String)> {
    
    let mut tx = pool.begin().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Transaction failed".to_string()))?;

    issue_repository::update_issue_status(&mut tx, issue_id, &payload.status)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let (created_by, title) = issue_repository::find_issue_basic_info(&mut tx, issue_id)
        .await
        .map_err(|_| (StatusCode::NOT_FOUND, "Issue not found".to_string()))?;

    let msg = format!("Your issue '{}' has been {}.", title, payload.status.to_lowercase());

    issue_repository::insert_notification(&mut tx, "ISSUE_STATUS_UPDATE", &msg, &created_by.to_string())
        .await
        .ok();

    tx.commit().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Commit failed".to_string()))?;

    Ok(())
}

pub async fn delete_issue(
    pool: &PgPool,
    issue_id: Uuid,
) -> Result<(), (StatusCode, String)> {
    issue_repository::delete_issue_comments(pool, issue_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to delete comments: {}", e)))?;

    let rows_affected = issue_repository::delete_issue(pool, issue_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to delete issue: {}", e)))?;

    if rows_affected == 0 {
        return Err((StatusCode::NOT_FOUND, "Issue not found".to_string()));
    }

    Ok(())
}
