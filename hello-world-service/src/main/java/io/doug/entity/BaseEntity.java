package io.doug.entity;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.NoArgsConstructor;

import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.MappedSuperclass;

@NoArgsConstructor
@MappedSuperclass
@JsonIgnoreProperties(value={"hibernateLazyInitializer","handler","fieldHandler"})
public class BaseEntity {

    private Long id;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }
}
