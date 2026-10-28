package com.example.service.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

// Uses PanacheEntityBase + an explicit IDENTITY id (rather than plain
// PanacheEntity, whose default id strategy expects a Hibernate-managed
// sequence) so the entity lines up with the hand-written Flyway migration's
// "generated always as identity" columns.
@Entity
public class PizzaItem extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    @ManyToOne
    @JoinColumn(name = "order_id")
    public PizzaOrder order;

    @Enumerated(EnumType.STRING)
    public PizzaSize size;

    @ElementCollection
    @CollectionTable(name = "pizza_item_topping", joinColumns = @JoinColumn(name = "pizza_item_id"))
    @Column(name = "topping")
    public List<String> toppings = new ArrayList<>();

    public BigDecimal price;

    // Panache favors public fields over getters, but Drools' DRL compiler
    // needs a JavaBean-style getter to resolve the type of any property
    // that's then called with a method in a rule constraint (e.g.
    // `toppings.size()` in pizza-rules.drl) - plain field access alone
    // works for simple equality/null checks but not that.
    public List<String> getToppings() {
        return toppings;
    }

    public PizzaSize getSize() {
        return size;
    }
}
