use sqlx::{PgPool};
use axum::http::StatusCode;
use crate::models::{Notification, NotificationQuery};
use crate::repositories::common::notification_repository;

pub async fn get_notifications(
    pool: &PgPool,
    params: NotificationQuery,
) -> Result<Vec<Notification>, StatusCode> {
    notification_repository::find_notifications(pool, params)
        .await
        .map_err(|e| {
            eprintln!("Get Notifications Error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })
}

pub async fn delete_notifications(
    pool: &PgPool,
    ids: Vec<uuid::Uuid>,
) -> Result<(), StatusCode> {
    notification_repository::delete_notifications(pool, ids)
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}
