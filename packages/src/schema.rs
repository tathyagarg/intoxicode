// @generated automatically by Diesel CLI.

diesel::table! {
    packages (name, version) {
        name -> Text,
        version -> Text,
        description -> Nullable<Text>,
        author -> Nullable<Text>,
        time_created -> Nullable<Timestamp>,
    }
}

diesel::table! {
    users (rowid) {
        rowid -> Integer,
        username -> Text,
        salt -> Text,
        password -> Text,
    }
}

diesel::allow_tables_to_appear_in_same_query!(
    packages,
    users,
);
