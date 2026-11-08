package org.acme.greeting;

import io.quarkus.hibernate.orm.panache.PanacheEntity;

import javax.persistence.Entity;

@Entity
public class Greeting extends PanacheEntity {
    public String message;
}
