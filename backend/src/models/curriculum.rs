use serde::{Deserialize, Serialize};
use uuid::Uuid;
use sqlx::FromRow;
use chrono::{DateTime, Utc, NaiveDate};

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct CurriculumJson {
    pub subject_code: String,
    pub subject_name: String,
    pub regulation: String,
    pub semester: i32,
    pub total_periods: i32,
    pub units: Vec<CurriculumUnit>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct CurriculumUnit {
    pub unit_no: i32,
    pub title: String,
    pub total_periods: i32,
    pub topics: Vec<CurriculumTopic>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct CurriculumTopic {
    pub id: String,
    pub sno: String,
    pub topic: String,
    pub period: i32,
    #[serde(rename = "type")]
    pub topic_type: String,
    // These will be populated from DB during merge
    #[serde(skip_deserializing)]
    pub status: Option<String>,
    #[serde(skip_deserializing)]
    pub assigned_date: Option<NaiveDate>,
    #[serde(skip_deserializing)]
    pub completed_date: Option<NaiveDate>,
    #[serde(skip_deserializing)]
    pub remarks: Option<String>,
    #[serde(skip_deserializing)]
    pub feedback_count: Option<i32>,
    #[serde(skip_deserializing)]
    pub understood_percentage: Option<f64>,
}

#[derive(Debug, FromRow, Serialize, Deserialize)]
pub struct CurriculumProgressRow {
    pub id: Uuid,
    pub topic_id: String,
    pub subject_code: String,
    pub faculty_id: Uuid,
    pub branch: String,
    pub section: String,
    pub year: String,
    pub semester: i32,
    pub assigned_date: Option<NaiveDate>,
    pub completed_date: Option<NaiveDate>,
    pub status: Option<String>,
    pub remarks: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateProgressRequest {
    pub topic_id: String,
    pub subject_code: String,
    pub faculty_id: Uuid,
    pub branch: String,
    pub section: String,
    pub year: String,
    pub semester: i32,
    pub assigned_date: Option<NaiveDate>,
    pub completed_date: Option<NaiveDate>,
    pub status: String,
    pub remarks: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SubmitFeedbackRequest {
    pub topic_id: String,
    pub subject_code: String,
    pub understood: Option<bool>,
    pub rating: Option<i32>,
    pub issue_type: Option<String>,
    pub comment: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct HodCurriculumAnalytics {
    pub subject_code: String,
    pub subject_name: String,
    pub faculty_name: String,
    pub section: String,
    pub total_topics: usize,
    pub completed_topics: usize,
    pub completion_percentage: f64,
    pub pending_topics: usize,
    pub last_updated: Option<DateTime<Utc>>,
}
