package com.locationshare.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class LocationShareBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(LocationShareBackendApplication.class, args);
    }
}
