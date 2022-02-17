package io.doug.repository;

import com.cashstar.entity.HelloWorld;
import io.micronaut.data.annotation.Repository;
import io.micronaut.data.jpa.repository.JpaRepository;

import javax.transaction.Transactional;
import java.util.Optional;

@Repository
@Transactional
public interface HelloWorldRepository extends JpaRepository<HelloWorld, Long> {
    Optional<HelloWorld> findByText(String text);
}
