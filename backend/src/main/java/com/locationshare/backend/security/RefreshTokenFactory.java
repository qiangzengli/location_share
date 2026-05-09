package com.locationshare.backend.security;

import org.springframework.stereotype.Component;

import java.security.SecureRandom;
import java.util.HexFormat;

@Component
public class RefreshTokenFactory {

    private static final SecureRandom RANDOM = new SecureRandom();
    private static final HexFormat HEX = HexFormat.of();

    /** 32 字节随机数，十六进制 64 字符 */
    public String newRawToken() {
        byte[] buf = new byte[32];
        RANDOM.nextBytes(buf);
        return HEX.formatHex(buf);
    }
}
