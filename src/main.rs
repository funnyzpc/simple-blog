pub mod error_handles;
pub mod blog_handles;
pub mod index_handles;

use handlebars::Handlebars;
use std::io;
use log::LevelFilter;

#[macro_use]
extern crate actix_web;
#[macro_use]
extern crate serde_json;
#[macro_use]
extern crate log;
extern crate env_logger;
// #[macro_use]
// extern crate sqlx;
use actix_web::{web, App, HttpServer};
use std::time::Duration;
use sqlx::postgres::{PgPoolOptions, PgConnectOptions, PgSslMode};
use sqlx::ConnectOptions;

#[actix_web::main]
async fn main() -> io::Result<()> {
    // log
    std::env::set_var("RUST_LOG", "actix_server=debug,actix_web=info,sqlx=debug,blog_handles=debug");
    env_logger::init();
    // init db
    let mut options = PgConnectOptions::new()
        .application_name("rust-handlebar")
        .host("127.0.0.1")
        .port(6789)
        .username("mee")
        .database("mee")
        .password("PASSWORD")
        .ssl_mode(PgSslMode::Disable)
        .statement_cache_capacity(240);
        options.log_statements(LevelFilter::Debug)
               .log_slow_statements(LevelFilter::Error, Duration::from_secs(3))
        ;
    info!("db pool连接信息:{:?}",options);
    let pool = PgPoolOptions::new()
        .min_connections(1)
        .max_connections(4)
        .max_lifetime(Some(Duration::from_secs(600)))
        .connect_timeout(Duration::from_secs(30))
        .connect_with(options)
        .await.unwrap();

    // std::env::set_var("GLOBAL", "MEE");
    let handlebars = Handlebars::new();
    // handlebars.register_templates_directory(".html", "../templates").unwrap();
    let handlebars_ref = web::Data::new(handlebars);

    HttpServer::new(move || {
        App::new()
            .wrap(error_handles::error_handles())
            .app_data(handlebars_ref.clone())

            // .route("/",web::get().to(index_handles::index))
            // .route("/blog",web::get().to(index_handles::index))
            // .route("/blog/data",web::get().to(blog_handles::data))
            // .route("/blog/{id}",web::get().to(blog_handles::blog))
            // home page
            .service(index_handles::index)
            .service(web::scope("/blog")
                .service(blog_handles::list)
                .service(blog_handles::blog))
            .data(pool.clone())
    })
    .bind("0.0.0.0:80")?
    .run()
    .await
}
use serde::{Serialize};

#[derive(Serialize, Debug, Clone)]
pub struct TBLOG2 {
    pub id: String,
    pub subject: String,
    pub title: String,
    pub content: String,
    pub user_id: Option<String>,
    pub visited: Option<String>,
    pub type_alias: Option<String>,
    pub status: Option<String>,
    pub update_date: Option<String>,
    //pub update_date: Option<PrimitiveDateTime>,
    pub create_date: Option<String>,
}

#[test]
fn test_with_in_each() {

    let blog1 = TBLOG2 {
        id: "00001".to_string(),
        title: "title001".to_string(),
        create_date: Some(String::from("2020-02-02")),
        subject:"".to_string(),
        content:"".to_string(),
        user_id:None,
        visited:None,
        type_alias:None,
        status:None,
        update_date:None,
    };

    let blog2 = TBLOG2 {
        id: "00001".to_string(),
        title: "title001".to_string(),
        create_date: Some(String::from("2020-02-02")),
        subject:"".to_string(),
        content:"".to_string(),
        user_id:None,
        visited:None,
        type_alias:None,
        status:None,
        update_date:None,
    };

    let ttt = vec![blog1, blog2];
    let t = r#"{{#each this}}<p><time>{{create_date}}</time> <a href="/blog/{{id}}">{{title}}</a> <small><em> {{origin}} </em></small></p>{{/each}}"#;
    let handlebars = Handlebars::new();
    let  result = handlebars.render_template(t,&ttt);
    println!("{:?}",result)

}

