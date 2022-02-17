package io.doug.entity;

import javax.persistence.Entity;

@Entity
//@Table(name="HelloWorld", schema = "mock_processor")
public class HelloWorld extends BaseEntity {
    private String text;

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }
}
