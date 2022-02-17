package io.doug.service;

import com.cashstar.entity.HelloWorld;

import java.util.List;

public interface HelloWorldService {

    List<HelloWorld> findAll();
    HelloWorld findByText(String text);
    HelloWorld save(HelloWorld helloWorld);
    boolean delete(Long id);
}
