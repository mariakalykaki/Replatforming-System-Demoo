package com.example.service.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Entity
public class PizzaOrder extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    public String customerName;

    @Enumerated(EnumType.STRING)
    public OrderStatus status;

    public BigDecimal totalPrice;

    public String rejectionReason;

    public Instant createdAt;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    public List<PizzaItem> items = new ArrayList<>();

    // Panache favors public fields over getters, but Drools' DRL compiler
    // needs a JavaBean-style getter to resolve the type of any property
    // that's then called with a method in a rule constraint (e.g.
    // `totalPrice.doubleValue() < 10.00` in pizza-rules.drl) - plain field
    // access alone works for simple equality/null checks but not that.
    public BigDecimal getTotalPrice() {
        return totalPrice;
    }

    public List<PizzaItem> getItems() {
        return items;
    }
}
