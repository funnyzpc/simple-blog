use actix_web::body::Body;
use actix_web::dev::ServiceResponse;
use actix_web::http::StatusCode;
use actix_web::{Result, web, HttpResponse};
use handlebars::Handlebars;
use actix_web::middleware::{ErrorHandlers, ErrorHandlerResponse};

// 错误代理
pub fn error_handles() -> ErrorHandlers<Body> {
    ErrorHandlers::new().handler(StatusCode::NOT_FOUND, not_found)
}

fn not_found<B>(res: ServiceResponse<B>) -> Result<ErrorHandlerResponse<B>> {
    let response = get_error_response(&res, "Page not found.");
    Ok(ErrorHandlerResponse::Response(
        res.into_response(response.into_body()),
    ))
}

const ERROR_HTML:&str = r#"<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>错误。。。</title></head><body><h1>{{status_code}}-{{error}}</h1></body></html>"#;
fn get_error_response<B>(res: &ServiceResponse<B>, error: &str) -> HttpResponse<Body> {
    let request = res.request();
    let fallback = |e: &str| {
        HttpResponse::NotFound().content_type("text/plain").body(e.to_string())
    };
    let hb = request
        .app_data::<web::Data<Handlebars>>()
        .map(|t| t.get_ref());
    match hb {
        Some(hb) => {
            let data = json!({"error":error,"status_code":res.status().as_str()});
            // let body = hb.render("error", &data);
            let body = hb.render_template(ERROR_HTML, &data);
            match body {
                //Ok(body) => Response::build(res.status()).content_type("text/html").body(body),
                Ok(body)=>HttpResponse::Ok().content_type("text/html").body(body),
                Err(_) => fallback(error),
            }
        }
        None => fallback(error),
    }
}
