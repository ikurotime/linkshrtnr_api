use askama::Template;
use axum::{
    http::StatusCode,
    response::{Html, IntoResponse, Response},
    routing::get,
    Router,
};

pub fn get_routes() -> Router {
    Router::new()
        .route("/", get(get_index))
        .route("/another_page", get(get_another_page))
        .route("/register", get(get_register))
        .route("/login", get(get_login))
        .route("/404", get(get_not_found))
}
async fn get_not_found() -> impl IntoResponse {
    let template = NotFoundPageTemplate {};
    HtmlTemplate(template)
}

#[derive(Template)]
#[template(path = "pages/404.html")]
struct NotFoundPageTemplate;

async fn get_login() -> impl IntoResponse {
    let template = LoginPageTemplate {};
    HtmlTemplate(template)
}

#[derive(Template)]
#[template(path = "pages/login.html")]
struct LoginPageTemplate;

async fn get_register() -> impl IntoResponse {
    let template = RegisterPageTemplate {};
    HtmlTemplate(template)
}

#[derive(Template)]
#[template(path = "pages/register.html")]
struct RegisterPageTemplate;

async fn get_another_page() -> impl IntoResponse {
    let template = AnotherPageTemplate {};
    HtmlTemplate(template)
}

#[derive(Template)]
#[template(path = "pages/another_page.html")]
struct AnotherPageTemplate;

async fn get_index() -> impl IntoResponse {
    let template = IndexTemplate {};
    HtmlTemplate(template)
}

#[derive(Template)]
#[template(path = "pages/index.html")]
struct IndexTemplate;
struct HtmlTemplate<T>(T);

impl<T> IntoResponse for HtmlTemplate<T>
where
    T: Template,
{
    fn into_response(self) -> Response {
        match self.0.render() {
            Ok(html) => Html(html).into_response(),
            Err(e) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("Template error: {}", e),
            )
                .into_response(),
        }
    }
}
