package com.example.app;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;

@WebServlet(name = "hello", urlPatterns = {"/"})
public class HelloController extends HttpServlet {
  @Override
  protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
    resp.setContentType("text/plain; charset=UTF-8");
    resp.getWriter().println("Hello from Tomcat in Docker by Max Phan setup! ✔");
  }
}
