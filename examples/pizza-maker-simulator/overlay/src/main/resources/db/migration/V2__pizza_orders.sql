create table pizza_order (
    id bigint generated always as identity primary key,
    customer_name varchar(255) not null,
    status varchar(20) not null,
    total_price numeric(10,2) not null,
    rejection_reason varchar(500),
    created_at timestamp not null
);

create table pizza_item (
    id bigint generated always as identity primary key,
    order_id bigint not null references pizza_order(id),
    size varchar(10) not null,
    price numeric(10,2) not null
);

create table pizza_item_topping (
    pizza_item_id bigint not null references pizza_item(id),
    topping varchar(100) not null
);
