local helpers = require "spec.helpers"
local cjson   = require "cjson"
local meta    = require "kong.meta"


local server_tokens = meta._SERVER_TOKENS


for _, strategy in helpers.each_strategy() do
  describe("Plugin: request-termination (access) [#" .. strategy .. "]", function()
    local proxy_client
    local admin_client

    lazy_setup(function()
      local bp, db = helpers.get_db_utils(strategy, {
        "routes",
        "services",
        "plugins",
      })

      local route1 = bp.routes:insert({
        hosts = { "api1.request-termination.com" },
      })

      local route2 = bp.routes:insert({
        hosts = { "api2.request-termination.com" },
      })

      local route3 = bp.routes:insert({
        hosts = { "api3.request-termination.com" },
      })

      local route4 = bp.routes:insert({
        hosts = { "api4.request-termination.com" },
      })

      local route5 = bp.routes:insert({
        hosts = { "api5.request-termination.com" },
      })

      local route6 = bp.routes:insert({
        hosts = { "api6.request-termination.com" },
      })

      local route7 = db.routes:insert({
        hosts = { "api7.request-termination.com" },
      })

      local route8 = bp.routes:insert({
        hosts = { "api8.request-termination.com" },
      })

      local route9 = bp.routes:insert({
        hosts = { "api9.request-termination.com" },
        strip_path = false,
        paths = { "~/(?<parameter>[^#?/]+)/200" }
      })

      local route10 = bp.routes:insert({
        hosts = { "api10.request-termination.com" },
      })

      bp.plugins:insert {
        name   = "request-termination",
        route  = { id = route1.id },
        config = {},
      }

      bp.plugins:insert {
        name   = "request-termination",
        route  = { id = route2.id },
        config = {
          status_code = 404,
        },
      }

      bp.plugins:insert {
        name   = "request-termination",
        route  = { id = route3.id },
        config = {
          status_code = 406,
          message     = "Invalid",
        },
      }

      bp.plugins:insert {
        name   = "request-termination",
        route  = { id = route4.id },
        config = {
          body = "<html><body><h1>Service is down for maintenance</h1></body></html>",
        },
      }

      bp.plugins:insert {
        name   = "request-termination",
        route  = { id = route5.id },
        config = {
          status_code  = 451,
          content_type = "text/html",
          body         = "<html><body><h1>Service is down due to content infringement</h1></body></html>",
        },
      }

      bp.plugins:insert {
        name   = "request-termination",
        route  = { id = route6.id },
        config = {
          status_code = 503,
          body        = '{"code": 1, "message": "Service unavailable"}',
        },
      }

      bp.plugins:insert {
        name   = "request-termination",
        route  = { id = route7.id },
        config = {},
      }

      bp.plugins:insert {
        name   = "request-termination",
        route  = { id = route8.id },
        config = {
          status_code = 204
        },
      }

      bp.plugins:insert {
        name   = "request-termination",
        route  = { id = route9.id },
        config = {
          echo = true,
          status_code = 404
        },
      }

      bp.plugins:insert {
        name   = "request-termination",
        route  = { id = route10.id },
        config = {
          echo = true,
          trigger = "gimme-an-echo",
          status_code = 404
        },
      }

      local route_grpc_1 = assert(bp.routes:insert {
        protocols = { "grpc" },
        paths = { "/hello.HelloService/" },
        service = assert(bp.services:insert {
          name = "grpc",
          url = helpers.grpcbin_url,
        }),
      })

      bp.plugins:insert {
        name   = "request-termination",
        route  = { id = route_grpc_1.id },
        config = {
          status_code = 503,
        },
      }

      assert(helpers.start_kong({
        database   = strategy,
        nginx_conf = "spec/fixtures/custom_nginx.template",
        headers_upstream = "off",
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong()
    end)

    before_each(function()
      proxy_client = helpers.proxy_client()
      admin_client = helpers.admin_client()
    end)

    after_each(function()
      if proxy_client then
        proxy_client:close()
      end
      if admin_client then
        admin_client:close()
      end
    end)

    describe("status code and message", function()
      it("default status code and message", function()
        local res = assert(proxy_client:send {
          method = "GET",
          path = "/status/200",
          headers = {
            ["Host"] = "api1.request-termination.com"
          }
        })
        local body = assert.res_status(503, res)
        local json = cjson.decode(body)
        assert.same({ message = "Service unavailable" }, json)
      end)

      it("default status code and message with serviceless route", function()
        local res = assert(proxy_client:send {
          method = "GET",
          path = "/status/200",
          headers = {
            ["Host"] = "api7.request-termination.com"
          }
        })
        local body = assert.res_status(503, res)
        local json = cjson.decode(body)
        assert.same({ message = "Service unavailable" }, json)
      end)

      it("status code with default message", function()
        local res = assert(proxy_client:send {
          method = "GET",
          path = "/status/200",
          headers = {
            ["Host"] = "api2.request-termination.com"
          }
        })
        local body = assert.res_status(404, res)
        local json = cjson.decode(body)
        assert.same({ message = "Not found" }, json)
      end)

      it("status code with custom message", function()
        local res = assert(proxy_client:send {
          method = "GET",
          path = "/status/200",
          headers = {
            ["Host"] = "api3.request-termination.com"
          }
        })
        local body = assert.res_status(406, res)
        local json = cjson.decode(body)
        assert.same({ message = "Invalid" }, json)
      end)

      it("returns 204 without content length header", function()
        local res = assert(proxy_client:send {
          method = "GET",
          path = "/status/204",
          headers = {
            ["Host"] = "api8.request-termination.com"
          }
        })

        assert.res_status(204, res)
        assert.is_nil(res.headers["Content-Length"])
      end)

    end)

    describe("status code and body", function()
      it("default status code and body", function()
        local res = assert(proxy_client:send {
          method = "GET",
          path = "/status/200",
          headers = {
            ["Host"] = "api4.request-termination.com"
          }
        })
        local body = assert.res_status(503, res)
        assert.equal([[<html><body><h1>Service is down for maintenance</h1></body></html>]], body)
      end)

      it("status code with default message", function()
        local res = assert(proxy_client:send {
          method = "GET",
          path = "/status/200",
          headers = {
            ["Host"] = "api5.request-termination.com"
          }
        })
        local body = assert.res_status(451, res)
        assert.equal([[<html><body><h1>Service is down due to content infringement</h1></body></html>]], body)
      end)

      it("status code with default message #grpc", function()
        local ok, res = helpers.proxy_client_grpc(){
          service = "hello.HelloService.SayHello",
          opts = {
            ["-v"] = true,
          },
        }
        assert.falsy(ok)
        assert.matches("Code: Unavailable", res)
      end)

      it("status code with custom message", function()
        local res = assert(proxy_client:send {
          method = "GET",
          path = "/status/200",
          headers = {
            ["Host"] = "api6.request-termination.com"
          }
        })
        local body = assert.res_status(503, res)
        local json = cjson.decode(body)
        assert.same({ code = 1, message = "Service unavailable" }, json)
      end)
    end)

    it("returns server tokens with Server header", function()
      local res = assert(proxy_client:send {
        method = "GET",
        path = "/status/200",
        headers = {
          ["Host"] = "api1.request-termination.com"
        }
      })

      assert.equal(server_tokens, res.headers["Server"])
    end)

    describe("echo & trigger", function()
      it("echos a request if no trigger is set", function()
        local res = assert(proxy_client:send {
          method = "GET",
          query = {
            hello = "there",
          },
          path = "/status/200",
          headers = {
            ["Host"] = "api9.request-termination.com"
          },
          body = "cool body",
        })
        assert.response(res).has.status(404)
        local json = assert.response(res).has.jsonbody()
        assert.equal("api9.request-termination.com", json.matched_route.hosts[1])
        json.request.headers["user-agent"] = nil -- clear, depends on lua-resty-http version
        assert.same({
          headers = {
            ["content-length"] = '9',
            host = 'api9.request-termination.com',
          },
          host = 'api9.request-termination.com',
          method = 'GET',
          path = '/status/200',
          port = helpers.get_proxy_port(),
          query = {
            hello = 'there',
          },
          raw_body = 'cool body',
          scheme = 'http',
          uri_captures = {
            named = { parameter = "status" },
            unnamed = { "status" }
          },
        }, json.request)
      end)
      it("doesn't echo a request if the trigger is set but not specified", function()
        local res = assert(proxy_client:send {
          method = "GET",
          path = "/status/200",
          headers = {
            ["Host"] = "api10.request-termination.com"
          }
        })
        assert.response(res).has.status(200)
      end)
      it("echos a request if the trigger is specified as a header", function()
        local res = assert(proxy_client:send {
          method = "GET",
          query = {
            hello = "there",
          },
          path = "/status/200",
          headers = {
            ["Host"] = "api10.request-termination.com",
            ["Gimme-An-Echo"] = "anything will do"
          },
          body = "cool body",
        })
        assert.response(res).has.status(404)
        local json = assert.response(res).has.jsonbody()
        assert.equal("api10.request-termination.com", json.matched_route.hosts[1])
        json.request.headers["user-agent"] = nil -- clear, depends on lua-resty-http version
        assert.same({
          headers = {
            ["content-length"] = '9',
            ["gimme-an-echo"] = 'anything will do',
            host = 'api10.request-termination.com',
          },
          host = 'api10.request-termination.com',
          method = 'GET',
          path = '/status/200',
          port = helpers.get_proxy_port(),
          query = {
            hello = 'there',
          },
          raw_body = 'cool body',
          scheme = 'http',
          uri_captures = {
            named = {},
            unnamed = {}
          },
        }, json.request)
      end)
      it("echos a request if the trigger is specified as a query parameter", function()
        local res = assert(proxy_client:send {
          method = "GET",
          query = {
            hello = "there",
            ["gimme-an-echo"] = "anything will do"
            },
          path = "/status/200",
          headers = {
            ["Host"] = "api10.request-termination.com",
          },
          body = "cool body",
        })
        assert.response(res).has.status(404)
        local json = assert.response(res).has.jsonbody()
        assert.equal("api10.request-termination.com", json.matched_route.hosts[1])
        json.request.headers["user-agent"] = nil -- clear, depends on lua-resty-http version
        assert.same({
          headers = {
            ["content-length"] = '9',
            host = 'api10.request-termination.com',
          },
          host = 'api10.request-termination.com',
          method = 'GET',
          path = '/status/200',
          port = helpers.get_proxy_port(),
          query = {
            hello = 'there',
            ["gimme-an-echo"] = 'anything will do',
          },
          raw_body = 'cool body',
          scheme = 'http',
          uri_captures = {
            named = {},
            unnamed = {}
          },
        }, json.request)
      end)
    end)
  end)
end
