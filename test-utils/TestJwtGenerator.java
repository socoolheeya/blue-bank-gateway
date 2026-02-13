import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import javax.crypto.SecretKey;
import java.util.*;

public class TestJwtGenerator {
    public static void main(String[] args) {
        // application.yml에 설정된 시크릿 키
        String secret = "your-secret-key-must-be-at-least-256-bits-long-for-hs256-algorithm";
        SecretKey key = Keys.hmacShaKeyFor(secret.getBytes());

        // 토큰 만료 시간 (1년)
        long expirationTime = System.currentTimeMillis() + (365L * 24 * 60 * 60 * 1000);

        // JWT 토큰 생성
        String token = Jwts.builder()
            .setSubject("testuser")
            .claim("userId", "1")
            .claim("username", "testuser")
            .claim("role", "ADMIN")  // 주의: role (단수형)
            .claim("customerId", 1)
            .setIssuedAt(new Date())
            .setExpiration(new Date(expirationTime))
            .signWith(key)
            .compact();

        System.out.println("=== JWT Token for Blue Bank Gateway ===");
        System.out.println();
        System.out.println(token);
        System.out.println();
        System.out.println("=== Usage Examples ===");
        System.out.println();
        System.out.println("1. Test with curl (Account Service):");
        System.out.println("curl -H \"Authorization: Bearer " + token + "\" http://localhost:8080/api/accounts");
        System.out.println();
        System.out.println("2. Actuator endpoints (no auth needed):");
        System.out.println("curl http://localhost:8080/actuator/health");
        System.out.println("curl http://localhost:8080/actuator/gateway/routes");
    }
}