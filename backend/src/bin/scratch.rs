use serde::Deserialize;

#[derive(Deserialize, Debug)]
pub struct ApprovalRequest {
    #[serde(rename = "userId")]
    pub user_id: Option<String>,
    #[serde(rename = "requestId")]
    pub request_id: String,
    #[serde(rename = "senderId")]
    pub sender_id: String,
    pub action: String,
}

fn main() {
    let json = r#"{"requestId":"123","senderId":"456","action":"APPROVE"}"#;
    let req: Result<ApprovalRequest, _> = serde_json::from_str(json);
    println!("{:?}", req);
}
