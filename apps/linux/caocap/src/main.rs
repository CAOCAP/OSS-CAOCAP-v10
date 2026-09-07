use adw::prelude::*;
use gtk::prelude::*;

fn main() {
    let app = adw::Application::builder()
        .application_id("com.ficruty.caocap")
        .build();

    app.connect_activate(build_ui);
    app.run();
}

fn build_ui(app: &adw::Application) {
    let label = gtk::Label::builder()
        .label("Hello, world!")
        .margin_top(24)
        .margin_bottom(24)
        .margin_start(24)
        .margin_end(24)
        .build();

    let window = adw::ApplicationWindow::builder()
        .application(app)
        .title("CAOCAP")
        .default_width(480)
        .default_height(320)
        .content(&label)
        .build();

    window.present();
}
