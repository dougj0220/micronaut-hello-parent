package io.doug.controller;

import com.cashstar.entity.HelloWorld;
import com.cashstar.service.HelloWorldService;
import com.cashstar.util.ApiResponse;
import io.micronaut.http.HttpResponse;
import io.micronaut.http.MediaType;
import io.micronaut.http.annotation.Body;
import io.micronaut.http.annotation.Controller;
import io.micronaut.http.annotation.Delete;
import io.micronaut.http.annotation.Get;
import io.micronaut.http.annotation.PathVariable;
import io.micronaut.http.annotation.Post;
import io.micronaut.http.annotation.Produces;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Inject;
import java.util.List;

@Controller("/hello")
public class HelloWorldController {

    private final static Logger LOG = LoggerFactory.getLogger(HelloWorldController.class);

    private final HelloWorldService helloWorldService;

    @Inject
    public HelloWorldController(HelloWorldService helloWorldService) {
        this.helloWorldService = helloWorldService;
    }

    @Get("/list")
    @Produces(MediaType.APPLICATION_JSON)
    public HttpResponse<ApiResponse<List<HelloWorld>>> findAll() {
        LOG.info("find all hello world");
        ApiResponse<List<HelloWorld>> apiResponse = new ApiResponse<>("findAll() response",
                helloWorldService.findAll());
        return HttpResponse.ok(apiResponse);
    }

    @Get("/find/{text}")
    @Produces(MediaType.APPLICATION_JSON)
    public HttpResponse<ApiResponse> findByText(@PathVariable String text) {
        LOG.info("rest findByText: {}", text);
        ApiResponse<HelloWorld> apiResponse = new ApiResponse<>("findByText() response",
                helloWorldService.findByText(text));
        return HttpResponse.ok(apiResponse);
    }

    @Post
    @Produces(MediaType.APPLICATION_JSON)
    public HttpResponse<ApiResponse<HelloWorld>> save(@Body HelloWorld hellWorld) {
        LOG.info("rest saving new HelloWorld io.doug.entity");
        ApiResponse<HelloWorld> apiResponse = new ApiResponse<>("HelloWorld domain create response",
                helloWorldService.save(hellWorld));
        return HttpResponse.ok(apiResponse);
    }

    @Delete("/{id}")
    public HttpResponse<ApiResponse<Boolean> > delete(Long id) {
        LOG.info("deleting hello world by id: {}", id);
        // TODO: fix me and wrap ApiResponse --> HttpResponseWrapper or something like this
        ApiResponse<Boolean> apiResponse = new ApiResponse<>("HelloWorld domain delete response",
                helloWorldService.delete(id));
        return HttpResponse.ok(apiResponse);
    }
}
