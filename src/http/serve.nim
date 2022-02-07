# Madam 💋 A lightweight local web server for
# Design Prototyping 🎨 and Front-end Development 🌈
# 
# GPLv3 License
# Copyright (c) 2022 George Lemon from OpenPeep
# https://github.com/openpeep/madam

import std/[options, asyncdispatch, json]
import ./httpbeast, ./defaults
import ../assets, ../configurator, ../routes

from std/os import getCurrentDir, fileExists
from std/strutils import `%`, startsWith, replace
from klymene/cli import display

# proc isSecondaryPage(): bool =
#     return false

# proc getPageContents(): string =
#     readFile(filepath)

type
    Logger = object
        code: HttpCode
        verb: HttpMethod
        path: string

proc httpGetRequest(route: string, config: Configurator): tuple[code: HttpCode, body: string] =
    # Procedure for handling GET Requests for public routes and static assets
    let assetsEndpoint = "/assets/"
    var path = route
    var response = (code: Http404, body: defaults.getErrorPage)
    case path
    of "/":
        let indexFilePath = config.getViewsPath("index.html")
        if fileExists(indexFilePath):
            response = (code: Http200, body: readFile(indexFilePath))
        else:
            response = (code: Http200, body: defaults.getWelcomeScreen)
    else:
        if path.startsWith(assetsEndpoint):
            # try serve static assets if is in path
            path = replace(path, assetsEndpoint)
            if config.getAssets().hasFile(path):
                response = (code: Http200, body: config.getAssets().getFile(path))
        elif getExists(config.routes, path):
            let routeObject = getRoute(config.routes, HttpGet, path)
            if fileExists(routeObject.getFile()):
                response = (code: Http200, body: readFile(routeObject.getFile()))
    return response

proc httpPostRequests(route: string, config: Configurator): tuple[code: HttpCode, body: JsonNode] =
    var response = (code: Http404, body: %* {"message": "Page not found"})
    if postExists(config.routes, route):
        response = (code: Http200, body: %* {"message": "Alright"})
    return response

proc startHttpServer*(config: Configurator) =
    ## Start a Madam Server instance using current configuration
    let
        currentProject = getCurrentDir()
        localAddress = "127.0.0.1"
    proc onRequest(req: Request): Future[void] =
        let path = req.path.get()
        var logger = Logger()

        # Handle GET requests
        if req.httpMethod == some(HttpGet):
            let (code, body) = httpGetRequest(path, config)
            logger.code = code
            logger.verb = HttpGet
            logger.path = path
            req.send(code, body)
        
        # Handle POST requests
        elif req.httpMethod == some(HttpPost):
            let (code, body) = httpPostRequests(path, config)
            logger.code = code
            logger.verb = HttpPost
            logger.path = path
            req.send(code, $body)
        else:
            req.send(Http404, "nope")
        if config.hasEnabledLogger():
            display("$1 $2  ➤  $3" % [$logger.verb, $logger.code, logger.path], indent=2)
    run(onRequest, initSettings(port=Port(config.getPort()), bindAddr=localAddress))