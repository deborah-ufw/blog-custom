

Blog.Router =
  routes: []

  notFound: ->
      FlowRouter._notfoundRoute FlowRouter.current()

  replaceState: (path) ->
      FlowRouter.withReplaceState -> FlowRouter.go path

  go: (nameOrPath, params, options) ->
    router =
        Package['kadira:flow-router'].FlowRouter

    if /^\/|http/.test(nameOrPath)
      path = nameOrPath
    else
      route = _.findWhere @routes, name: nameOrPath
      if not route
        throw new Meteor.Error 500, "Route named '#{nameOrPath}' not found"
      options ?= {}
      url = new Iron.Url route.path
      path = url.resolve params, options
    router.go path

  getLocation: ->
      FlowRouter.watchPathChange()
      FlowRouter.current().path

  getParam: (key) ->
    location = @getLocation()
    url = null
    match = _.find @routes, (route) ->
      url = new Iron.Url route.path
      url.test location
    if match
      params = url.params(location)
      return params[key]

  pathFor: (name, params, options) ->
    route = _.findWhere @routes, name: name
    if not route
      throw new Meteor.Error 500, "Route named '#{name}' not found"
    opts = options and (options.hash or {})
    url = new Iron.Url route.path
    url.resolve params, opts

  getTemplate: ->
    location = @getLocation()
    url = null
    match = _.find @routes, (route) ->
      url = new Iron.Url route.path
      url.test location
    if match
      name = match.name

      # Tagged view uses 'blogIndex' template
      if name is 'blogTagged'
        name = 'blogIndex'

      # Custom template?
      if Blog.settings["#{name}Template"]
        name = Blog.settings["#{name}Template"]
      return name

  routeAll: (routes) ->
    @routes = routes


    # --------------------------------------------------------------------------
    # FLOW ROUTER

      Package['kadira:flow-router'].FlowRouter.route '/:any*',
        action: ->
          template = Blog.Router.getTemplate()
          if template
            if Blog.settings.blogLayoutTemplate
              layout = Blog.settings.blogLayoutTemplate
              BlazeLayout.render layout, template: template
            else
              BlazeLayout.render template
          else
            Blog.Router.notFound()


 
  Package['kadira:flow-router'].FlowRouter.wait()

Meteor.startup ->

  routes = []
  basePath =
    # Avoid double-slashes like '//tag/:tag' when basePath is '/'...
    if Blog.settings.basePath is '/'
      ''
    else
      Blog.settings.basePath
  adminBasePath =
    if Blog.settings.adminBasePath is '/'
      ''
    else
      Blog.settings.adminBasePath


  # ----------------------------------------------------------------------------
  # PUBLIC ROUTES


  # BLOG INDEX

  routes.push
    path: basePath or '/' # ...but ensure we don't have a route path of ''
    name: 'blogIndex'
    fastRender: ->
      @subscribe 'blog.authors'
      @subscribe 'blog.posts'

  # BLOG TAG

  routes.push
    path: basePath + '/tag/:tag'
    name: 'blogTagged'
    fastRender: (params) ->
      @subscribe 'blog.authors'
      @subscribe 'blog.taggedPosts', params.tag

  # SHOW BLOG

  routes.push
    path: basePath + '/:slug'
    name: 'blogShow'
    fastRender: (params) ->
      @subscribe 'blog.authors'
      @subscribe 'blog.singlePostBySlug', params.slug
      @subscribe 'blog.commentsBySlug', params.slug


  # ----------------------------------------------------------------------------
  # ADMIN ROUTES


  # BLOG ADMIN INDEX

  routes.push
    path: adminBasePath
    name: 'blogAdmin'

  # NEW/EDIT BLOG

  routes.push
    path: adminBasePath + '/edit/:id'
    name: 'blogAdminEdit'


  # ----------------------------------------------------------------------------
  # RSS


  if Meteor.isServer
    JsonRoutes.add 'GET', '/rss/posts', (req, res, next) ->
      res.write Meteor.call 'serveRSS'
      res.end()


  Blog.Router.routeAll routes

FlowRouter.initialize()
