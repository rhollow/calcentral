package edu.berkeley.calcentral.controllers;

import java.util.Map;

import javax.servlet.http.HttpServletRequest;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;

@Controller
public class TestController {
	@PreAuthorize("true")
	@RequestMapping(value = { "/dashboard" }, method = RequestMethod.GET)
	public String foo(
			Map<String, Object> model,
			HttpServletRequest request) {
		model.put("foo", "baZ");
		return "dashboard";
	}
}