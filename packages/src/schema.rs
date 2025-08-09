// @generated automatically by Diesel CLI.

diesel::table! {
    packages (rowid) {
        rowid -> Integer,
        name -> Text,
        version -> Text,
        description -> Nullable<Text>,
        author -> Nullable<Text>,
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
