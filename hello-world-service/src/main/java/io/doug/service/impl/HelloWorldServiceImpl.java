package io.doug.service.impl;

import com.cashstar.entity.HelloWorld;
import com.cashstar.repository.HelloWorldRepository;
import com.cashstar.service.HelloWorldService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Inject;
import javax.inject.Singleton;
import java.util.List;

// @RequiredArgsConstructor
@Singleton
public class HelloWorldServiceImpl implements HelloWorldService {

    private final static Logger LOG = LoggerFactory.getLogger(HelloWorldService.class);

    private final HelloWorldRepository helloWorldRepository;

    @Inject
    public HelloWorldServiceImpl(HelloWorldRepository helloWorldRepository) {
        this.helloWorldRepository = helloWorldRepository;
    }

    public List<HelloWorld> findAll() {
        LOG.info("finding all hello world entities");
        return helloWorldRepository.findAll();
    }

    public HelloWorld findByText(String text) {
        LOG.info("finding hello world by text: {}", text);
        return helloWorldRepository.findByText(text)
                .orElse(null);
    }

    public HelloWorld save(HelloWorld helloWorld) {
        // add any validation logic here..
        LOG.info("saving new hello world io.doug.entity");
        return helloWorldRepository.save(helloWorld);
    }

    public boolean delete(Long id) {
        try {
            helloWorldRepository.deleteById(id);
        } catch (Exception e) {
            LOG.warn("error deleting HelloWorld io.doug.entity by id: {id}");
            return false;
        }
        return true;
    }
}
