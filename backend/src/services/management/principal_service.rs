use sqlx::PgPool;
use axum::http::StatusCode;
use crate::models::AdminApprovalRequest;
use crate::repositories::management::principal_repository;

pub async fn principal_approve_hod(pool: &PgPool, payload: AdminApprovalRequest) -> Result<(), StatusCode> {
    if payload.action == "APPROVE" {
        principal_repository::approve_hod(pool, payload.user_id)
            .await
            .map(|_| ())
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    } else if payload.action == "REJECT" || payload.action == "DELETE" {
        principal_repository::delete_hod(pool, payload.user_id)
            .await
            .map(|_| ())
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    }
    Ok(())
}

pub async fn get_promotion_requests(pool: &PgPool) -> Result<Vec<crate::models::PromotionRequest>, StatusCode> {
    sqlx::query_as::<_, crate::models::PromotionRequest>("SELECT * FROM promotion_requests WHERE status = 'PENDING' ORDER BY created_at DESC")
        .fetch_all(pool)
        .await
        .map_err(|e| {
            eprintln!("Failed to fetch promotion requests: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })
}

pub async fn approve_promotion(pool: &PgPool, payload: crate::models::ApprovePromotionRequest) -> Result<serde_json::Value, StatusCode> {
    let req_uuid = uuid::Uuid::parse_str(&payload.request_id).map_err(|_| StatusCode::BAD_REQUEST)?;

    if payload.action == "APPROVE" {
        // Find branch
        let req: crate::models::PromotionRequest = sqlx::query_as("SELECT * FROM promotion_requests WHERE id = $1")
            .bind(req_uuid)
            .fetch_one(pool)
            .await
            .map_err(|_| StatusCode::NOT_FOUND)?;

        sqlx::query("UPDATE promotion_requests SET status = 'APPROVED', updated_at = NOW() WHERE id = $1")
            .bind(req_uuid)
            .execute(pool)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

        match crate::repositories::management::admin_repository::promote_students(pool, Some(&req.branch)).await {
            Ok(affected) => Ok(serde_json::json!({
                "success": true,
                "message": format!("Successfully approved promotion and updated {} students", affected)
            })),
            Err(e) => {
                eprintln!("Promote Students Error: {:?}", e);
                Err(StatusCode::INTERNAL_SERVER_ERROR)
            }
        }
    } else {
        sqlx::query("UPDATE promotion_requests SET status = 'REJECTED', updated_at = NOW() WHERE id = $1")
            .bind(req_uuid)
            .execute(pool)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

        Ok(serde_json::json!({
            "success": true,
            "message": "Promotion request rejected"
        }))
    }
}
