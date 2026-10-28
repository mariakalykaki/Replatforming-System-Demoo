package com.example.service.resource;

import com.example.service.domain.OrderStatus;
import com.example.service.domain.PizzaItem;
import com.example.service.domain.PizzaOrder;
import com.example.service.domain.PizzaSize;
import com.example.service.resource.dto.CreateOrderRequest;
import com.example.service.resource.dto.OrderResponse;
import com.example.service.resource.dto.PizzaRequest;
import com.example.service.routes.PaymentRequest;
import com.example.service.routes.PaymentResult;
import com.example.service.validation.OrderValidationResult;
import com.example.service.validation.PizzaOrderValidator;
import com.example.service.workflow.PizzaOrderWorkflow;
import io.temporal.client.WorkflowClient;
import io.temporal.client.WorkflowOptions;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.apache.camel.ProducerTemplate;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

@Path("/orders")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class OrderResource {

    private static final BigDecimal TOPPING_PRICE = new BigDecimal("1.50");

    @Inject
    PizzaOrderValidator validator;

    @Inject
    ProducerTemplate producerTemplate;

    @Inject
    WorkflowClient workflowClient;

    @ConfigProperty(name = "temporal.task-queue")
    String taskQueue;

    // @Transactional spans the Drools check, the (mocked) payment HTTP call,
    // and the persist - fine for this sandbox, but in a real service you
    // wouldn't want a DB transaction held open across an external HTTP call.
    @POST
    @Transactional
    public Response createOrder(CreateOrderRequest request) {
        PizzaOrder order = new PizzaOrder();
        order.customerName = request.customerName;
        order.status = OrderStatus.RECEIVED;
        order.createdAt = Instant.now();
        order.items = request.pizzas.stream().map(this::toItem).collect(Collectors.toList());
        order.items.forEach(item -> item.order = order);
        order.totalPrice = order.items.stream()
                .map(item -> item.price)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        int kitchenLoad = (int) PizzaOrder.count(
                "status in (?1, ?2)", OrderStatus.PREPARING, OrderStatus.BAKING);
        OrderValidationResult verdict = validator.validate(order, kitchenLoad);
        if (verdict.isRejected()) {
            order.status = OrderStatus.REJECTED;
            order.rejectionReason = String.join(" ", verdict.getReasons());
            order.persist();
            return Response.status(Response.Status.BAD_REQUEST).entity(new OrderResponse(order)).build();
        }

        PaymentResult payment = producerTemplate.requestBody(
                "direct:chargePayment", new PaymentRequest(order.totalPrice), PaymentResult.class);
        if (!"APPROVED".equals(payment.status)) {
            order.status = OrderStatus.REJECTED;
            order.rejectionReason = "Payment declined.";
            order.persist();
            return Response.status(Response.Status.PAYMENT_REQUIRED).entity(new OrderResponse(order)).build();
        }

        order.persist();

        PizzaOrderWorkflow workflow = workflowClient.newWorkflowStub(
                PizzaOrderWorkflow.class,
                WorkflowOptions.newBuilder()
                        .setTaskQueue(taskQueue)
                        .setWorkflowId("pizza-order-" + order.id)
                        .build());
        WorkflowClient.start(workflow::run, order.id);

        return Response.status(Response.Status.ACCEPTED).entity(new OrderResponse(order)).build();
    }

    @GET
    @Path("/{id}")
    public Response getOrder(@PathParam("id") Long id) {
        PizzaOrder order = PizzaOrder.findById(id);
        if (order == null) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        return Response.ok(new OrderResponse(order)).build();
    }

    private PizzaItem toItem(PizzaRequest req) {
        PizzaItem item = new PizzaItem();
        item.size = PizzaSize.valueOf(req.size.toUpperCase());
        item.toppings = req.toppings == null ? List.of() : req.toppings;
        item.price = basePrice(item.size).add(TOPPING_PRICE.multiply(BigDecimal.valueOf(item.toppings.size())));
        return item;
    }

    private BigDecimal basePrice(PizzaSize size) {
        return switch (size) {
            case SMALL -> new BigDecimal("8.00");
            case MEDIUM -> new BigDecimal("11.00");
            case LARGE -> new BigDecimal("14.00");
        };
    }
}
