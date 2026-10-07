---
name: hexagonal
description: Genera o revisa código Java/Spring Boot siguiendo la arquitectura hexagonal (puertos y adaptadores) con las convenciones exactas de la cátedra de Programación 2 (UM). Usar cuando se pida crear un slice/feature nuevo, agregar un caso de uso, un endpoint, un repositorio, un mapper o un DTO en un proyecto Spring Boot hexagonal; o cuando haya que revisar si el código respeta las capas. Palabras clave: hexagonal, puertos y adaptadores, slice, use case, puerto in, puerto out, adapter, dominio, aplicación, infraestructura.
---

# Arquitectura Hexagonal — convenciones de la cátedra

Implementación particular de puertos y adaptadores. **Seguir estas convenciones al pie de la letra**, incluso cuando difieran de lo "canónico" que se encuentra en blogs o tutoriales. Las desviaciones más comunes están listadas al final.

Repo de referencia: https://github.com/dqmdz/hexagonal (slice `product`).

## Regla fundamental

**Lo de afuera conoce lo de adentro; lo de adentro NO conoce lo de afuera.**

```
INFRAESTRUCTURA  →  APLICACIÓN  →  DOMINIO
```

- `domain` NO puede tener imports de Spring, JPA, Jackson, Bean Validation, SLF4J ni ninguna librería de framework. Solo Java estándar y Lombok.
- `application` solo importa de `domain` (y Spring para `@Component`/`@Service`).
- `infrastructure` puede importar de todo.
- Si una clase de `domain` o `application` importa algo de `infrastructure`, el diseño está mal. Sin excepciones.

## Estructura de packages

Cada feature es un **slice**: un package de primer nivel bajo la raíz del proyecto, con las tres capas adentro. Nombre del slice en **singular** (`product`, `persona`, `factura`).

```
<raíz>.<slice>
├── domain
│   ├── model              → <Slice>.java                       (POJO puro)
│   └── ports
│       ├── in             → Create<Slice>UseCase.java, Get<Slice>ByIdUseCase.java,
│       │                     GetAll<Slice>sUseCase.java, Update<Slice>UseCase.java,
│       │                     Delete<Slice>UseCase.java          (una interfaz POR CASO DE USO)
│       └── out            → <Slice>Repository.java              (interfaz)
├── application
│   ├── usecases           → Create<Slice>UseCaseImpl.java, ...  (implementan los puertos in)
│   ├── service            → <Slice>Service.java                 (fachada, NO implementa puertos)
│   └── exception          → <Slice>Exception.java
└── infrastructure
    ├── persistence
    │   ├── entity         → <Slice>Entity.java                  (@Entity, JPA)
    │   ├── mapper         → <Slice>Mapper.java                  (dominio ↔ entity)
    │   ├── repository     → Jpa<Slice>Repository.java           (interfaz Spring Data)
    │   └── adapter        → Jpa<Slice>RepositoryAdapter.java    (implementa el puerto out)
    └── web
        ├── controller     → <Slice>Controller.java
        ├── dto            → <Slice>Request.java, <Slice>Response.java
        └── mapper         → <Slice>DtoMapper.java               (dominio ↔ DTOs)
```

## Plantillas por archivo

### domain/model/`<Slice>`.java
```java
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class Product {
    private Long id;
    private String description;
    private BigDecimal price;
}
```
Sin `@Entity`, sin `@Table`, sin anotaciones de Jackson ni de validación. Solo Lombok.

### domain/ports/out/`<Slice>`Repository.java
```java
public interface ProductRepository {
    Product create(Product product);
    Optional<Product> findById(Long id);
    List<Product> findAll();
    Optional<Product> update(Long id, Product product);
    boolean deleteById(Long id);
}
```
Siempre en términos del modelo de dominio, nunca de la entity. Devolver `Optional<T>` / `boolean` para informar ausencia; **nunca lanzar excepciones acá**.

### domain/ports/in/ — una interfaz por caso de uso
```java
public interface CreateProductUseCase    { Product createProduct(Product product); }
public interface GetProductByIdUseCase   { Optional<Product> getProductById(Long id); }
public interface GetAllProductsUseCase   { List<Product> getAllProducts(); }
public interface UpdateProductUseCase    { Optional<Product> updateProduct(Long id, Product product); }
public interface DeleteProductUseCase    { void deleteProduct(Long id); }
```
**Nunca** una sola interfaz con todos los métodos. El método se nombra con la acción + el slice (`createProduct`, no `create`).

### application/usecases/`<Caso>`UseCaseImpl.java
```java
@Component
@RequiredArgsConstructor
public class CreateProductUseCaseImpl implements CreateProductUseCase {

    private final ProductRepository productRepository;   // la INTERFAZ del puerto out

    @Override
    public Product createProduct(Product product) {
        return productRepository.create(product);
    }
}
```
`@Component` (no `@Service`). Propaga el `Optional` hacia arriba **sin interpretarlo**: no lanzar excepciones de "no encontrado" acá. Acá va la lógica de negocio si existe.

### application/service/`<Slice>`Service.java
```java
@Service
@RequiredArgsConstructor
public class ProductService {

    private final CreateProductUseCase createProductUseCase;
    private final GetProductByIdUseCase getProductByIdUseCase;
    private final GetAllProductsUseCase getAllProductsUseCase;
    private final UpdateProductUseCase updateProductUseCase;
    private final DeleteProductUseCase deleteProductUseCase;

    public Product createProduct(Product product) {
        return createProductUseCase.createProduct(product);
    }

    public Product getProductById(Long id) {
        return getProductByIdUseCase.getProductById(id)
                .orElseThrow(() -> new ProductException(id));
    }

    public List<Product> getAllProducts() {
        return getAllProductsUseCase.getAllProducts();
    }

    public Product updateProduct(Long id, Product product) {
        return updateProductUseCase.updateProduct(id, product)
                .orElseThrow(() -> new ProductException(id));
    }

    public void deleteProduct(Long id) {
        deleteProductUseCase.deleteProduct(id);
    }
}
```
`@Service`. Inyecta las **interfaces** `in`, nunca los `...Impl`. **Es el único lugar donde un `Optional` vacío se traduce en excepción de negocio** (`orElseThrow`) — así los use cases quedan reutilizables por otros consumidores que quieran reaccionar distinto ante la ausencia.

### application/exception/`<Slice>`Exception.java
```java
public class ProductException extends RuntimeException {
    public ProductException(Long id) {
        super("Could not find product with id: " + id);
    }
}
```
Siempre **unchecked** (`extends RuntimeException`).

### infrastructure/persistence/entity/`<Slice>`Entity.java
```java
@Entity
@Table(name = "products")
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class ProductEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String description;
    private BigDecimal price;
}
```
`@Table` con el nombre en **plural**. `@NoArgsConstructor` es obligatorio (JPA lo exige y `@Builder` lo desactiva). Clase separada del modelo de dominio **siempre**, aunque hoy tenga exactamente los mismos campos.

### infrastructure/persistence/mapper/`<Slice>`Mapper.java
```java
@Component
public class ProductMapper {

    public ProductEntity toEntity(Product product) {
        if (product == null) return null;
        return ProductEntity.builder()
                .id(product.getId())
                .description(product.getDescription())
                .price(product.getPrice())
                .build();
    }

    public Product toDomainModel(ProductEntity entity) {
        if (entity == null) return null;
        return Product.builder()
                .id(entity.getId())
                .description(entity.getDescription())
                .price(entity.getPrice())
                .build();
    }
}
```
Mapeo manual con builders, guarda de null en cada método. Nombres de método: `toEntity` / `toDomainModel`.

### infrastructure/persistence/repository/Jpa`<Slice>`Repository.java
```java
@Repository
public interface JpaProductRepository extends JpaRepository<ProductEntity, Long> { }
```
Solo trabaja con la entity. No implementa el puerto del dominio.

### infrastructure/persistence/adapter/Jpa`<Slice>`RepositoryAdapter.java
```java
@Component
@RequiredArgsConstructor
public class JpaProductRepositoryAdapter implements ProductRepository {

    private final JpaProductRepository jpaProductRepository;
    private final ProductMapper productMapper;

    @Override
    public Product create(Product product) {
        ProductEntity entity = productMapper.toEntity(product);
        ProductEntity saved = jpaProductRepository.save(entity);
        return productMapper.toDomainModel(saved);
    }

    @Override
    public Optional<Product> findById(Long id) {
        return jpaProductRepository.findById(id)
                .map(productMapper::toDomainModel);
    }

    @Override
    public List<Product> findAll() {
        return jpaProductRepository.findAll().stream()
                .map(productMapper::toDomainModel)
                .collect(Collectors.toList());
    }

    @Override
    public Optional<Product> update(Long id, Product product) {
        if (jpaProductRepository.existsById(id)) {
            ProductEntity entity = productMapper.toEntity(product);
            entity.setId(id);
            return Optional.of(productMapper.toDomainModel(jpaProductRepository.save(entity)));
        }
        return Optional.empty();
    }

    @Override
    public boolean deleteById(Long id) {
        if (jpaProductRepository.existsById(id)) {
            jpaProductRepository.deleteById(id);
            return true;
        }
        return false;
    }
}
```
Patrón fijo: **dominio → entity (mapper) → operación JPA → entity → dominio (mapper)**. Chequear `existsById` antes de update/delete y devolver `Optional.empty()`/`false` en lugar de lanzar.

### infrastructure/web/dto/
```java
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class ProductRequest {
    @NotBlank(message = "Description is mandatory")
    private String description;

    @NotNull(message = "Price is mandatory")
    @DecimalMin(value = "0.0", inclusive = false, message = "Price must be greater than 0")
    private BigDecimal price;
}

@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class ProductResponse {
    private Long id;
    private String description;
    private BigDecimal price;
}
```
El `Request` **no lleva `id`** (lo genera la base) y lleva las anotaciones de Bean Validation con `message` explícito. El `Response` sí lleva `id`. Las anotaciones de Jackson, si hacen falta, van acá — nunca en el modelo de dominio.

### infrastructure/web/mapper/`<Slice>`DtoMapper.java
```java
@Component
public class ProductDtoMapper {

    public Product toDomain(ProductRequest request) {
        if (request == null) return null;
        return Product.builder()
                .description(request.getDescription())
                .price(request.getPrice())
                .build();
    }

    public ProductResponse toResponse(Product domain) {
        if (domain == null) return null;
        return ProductResponse.builder()
                .id(domain.getId())
                .description(domain.getDescription())
                .price(domain.getPrice())
                .build();
    }
}
```
Nombres de método: `toDomain` / `toResponse`.

### infrastructure/web/controller/`<Slice>`Controller.java
```java
@RestController
@RequestMapping("/api/products")
@RequiredArgsConstructor
public class ProductController {

    private final ProductService productService;
    private final ProductDtoMapper productDtoMapper;

    @PostMapping
    public ResponseEntity<ProductResponse> createProduct(@Valid @RequestBody ProductRequest productRequest) {
        Product product = productDtoMapper.toDomain(productRequest);
        Product created = productService.createProduct(product);
        return new ResponseEntity<>(productDtoMapper.toResponse(created), HttpStatus.CREATED);
    }

    @GetMapping("/{id}")
    public ResponseEntity<ProductResponse> getProductById(@PathVariable Long id) {
        try {
            return ResponseEntity.ok(productDtoMapper.toResponse(productService.getProductById(id)));
        } catch (ProductException e) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }
    }

    @GetMapping
    public ResponseEntity<List<ProductResponse>> getAllProducts() {
        List<ProductResponse> responses = productService.getAllProducts().stream()
                .map(productDtoMapper::toResponse)
                .collect(Collectors.toList());
        return ResponseEntity.ok(responses);
    }

    @PutMapping("/{id}")
    public ResponseEntity<ProductResponse> updateProduct(@PathVariable Long id,
                                                         @Valid @RequestBody ProductRequest productRequest) {
        Product product = productDtoMapper.toDomain(productRequest);
        try {
            return ResponseEntity.ok(productDtoMapper.toResponse(productService.updateProduct(id, product)));
        } catch (ProductException e) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteProduct(@PathVariable Long id) {
        productService.deleteProduct(id);
        return ResponseEntity.noContent().build();
    }
}
```
Inyecta **solo** `<Slice>Service` + `<Slice>DtoMapper` (nunca los use cases directamente). `@RequestMapping` arranca con `/api/` para simplificar un eventual proxy reverso. Status codes: POST→201, GET→200, PUT→200, DELETE→204.

## Reglas de Spring y Lombok

| Regla | Detalle |
|---|---|
| Inyección | Campos `private final` + `@RequiredArgsConstructor`. **Nunca `@Autowired`** (ni en campo, ni en setter, ni en constructor). |
| `@Component` | Use cases, adapters, mappers. |
| `@Service` | Solo la fachada `<Slice>Service`. |
| `@Repository` | Solo la interfaz de Spring Data. |
| Lombok | Componer explícitamente: `@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor`. |
| **Nunca `@Data`** | Arrastra `@EqualsAndHashCode` sobre todos los campos (rompe `HashSet` cuando Hibernate asigna el `id` después de persistir) y `@ToString` (recursión infinita con relaciones bidireccionales). |
| `@Builder` | Siempre acompañado de `@NoArgsConstructor` + `@AllArgsConstructor`: `@Builder` desactiva el constructor vacío implícito que JPA necesita. |
| Excepciones | De negocio, siempre unchecked (`extends RuntimeException`). |
| Logging | `@Slf4j` de Lombok, con placeholders `log.info("... {}", valor)`. Solo en `infrastructure`; **nunca** en `domain` ni en use cases puros. |

## Checklist para un slice nuevo

1. Crear los 3 packages de capa dentro del slice.
2. `domain/model/<Slice>.java` — POJO con Lombok.
3. `domain/ports/out/<Slice>Repository.java` — interfaz con `Optional`/`boolean`.
4. `domain/ports/in/` — **una interfaz por cada caso de uso**.
5. `application/usecases/` — un `...Impl` por interfaz, `@Component`, inyectando el puerto out.
6. `application/exception/<Slice>Exception.java` — unchecked.
7. `application/service/<Slice>Service.java` — `@Service`, agrupa los use cases, traduce `Optional` vacío a excepción.
8. `infrastructure/persistence/` — entity, mapper, repository Spring Data, adapter.
9. `infrastructure/web/` — DTOs con validación, dto mapper, controller.
10. Verificar: ningún import de framework en `domain`; ningún import de `infrastructure` en `domain` ni en `application`.

## Errores a evitar

- Usar la `@Entity` como modelo de dominio (o anotar el modelo de dominio con `@Entity`).
- Una sola interfaz `<Slice>UseCase` con todos los métodos en vez de una por caso de uso.
- Que el `<Slice>Service` implemente un puerto, o que el controller inyecte use cases en vez del service.
- Lanzar excepciones de "no encontrado" en el adapter o en los use cases en vez del service.
- Inyectar la clase `...Impl` o `Jpa<Slice>RepositoryAdapter` en lugar de la interfaz.
- Devolver la entity o el modelo de dominio directamente desde el controller, sin pasar por DTO.
- `@Data`, `@Autowired`, o dos implementaciones de un mismo puerto `out` activas a la vez sin `@Profile` (rompe el arranque con `NoUniqueBeanDefinitionException`).

## Extensiones para este proyecto (turnos)

La plantilla de la cátedra cubre CRUD con persistencia y web. Este proyecto además tiene REST saliente hacia la cátedra, Redis, Kafka y un outbox. **Propuesta**, para mantener las mismas reglas de dependencia; confirmar con el profesor si hace falta:

- **Todo lo externo es un puerto `out`** en `domain/ports/out`, expresado en términos del dominio y sin tipos de framework: por ejemplo `CatedraApiClient` (holds, ocupaciones, cancelación), `CatalogCache` (lectura de Redis), `AdditionalInformationPublisher` (Kafka). Su adapter vive en `infrastructure/<tecnologia>` (`client`, `redis`, `messaging`), con sus propios DTOs y mapper hacia el dominio.
- **Los listeners de Kafka son adaptadores de entrada**, igual que el controller: `infrastructure/messaging` con `@KafkaListener`. Convierten el evento a un objeto de dominio y llaman al `<Slice>Service` (o al caso de uso); nunca contienen lógica de negocio ni tocan el repositorio.
- **Idempotencia y outbox**: la regla "ya procesé este `eventId`" y las transiciones de la máquina de estados son lógica de dominio/aplicación (use cases). Las tablas `processed_event` y `outbox` se acceden mediante puertos `out`, con entity y adapter en `infrastructure/persistence` como cualquier otro repositorio. El relay del outbox es un adaptador de entrada (`@Scheduled`) que llama a un caso de uso.
- **Excepciones de integración** (timeout, `409` de la cátedra) se traducen en el adapter `out` a resultados o excepciones del dominio; el `<Slice>Service` decide qué hacer. El controller sigue traduciendo excepciones a HTTP.
- **Seguridad**: el filtro JWT y la configuración de Spring Security son infraestructura. El `user_id` llega a los casos de uso como parámetro (nunca viene del body del cliente).
- **Slices sugeridos**: `catalogo` (categoría, profesional, horario, sincronización), `usuario` (si el servicio de catálogo emite el JWT) y, en el otro servicio, `reserva`. Cada servicio es un proyecto Spring Boot independiente con sus propios slices.
