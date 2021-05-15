use std::sync::Arc;
use once_cell::sync::OnceCell;
use serde::Deserialize;

// pub mod defs;

#[derive(Debug, Deserialize)]
pub struct Conf {
    pub server: Server,
    pub postgres: Postgresql,
}

#[derive(Debug, Deserialize)]
pub struct Server {
    pub port: u32,
    pub log: String,
    pub env: String,
}

#[derive(Debug, Deserialize)]
pub struct Postgresql {
    pub dsn: String,
    pub min: u32,
    pub max: u32,
}

pub fn global() -> &'static Arc<Conf> {
    static CONFIG: OnceCell<Arc<Conf>> = OnceCell::new();
    CONFIG.get_or_init(|| {
        let s = std::fs::read_to_string(&"config.yaml").unwrap();
        Arc::new(serde_yaml::from_str(&s).unwrap())
    })
}

impl Conf {
    pub fn addr(&self) -> String {
        format!("0.0.0.0:{}", self.server.port)
    }

    pub fn get_env(&self) -> String {
        self.server.env.clone()
    }
}
