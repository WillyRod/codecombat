RootView = require 'views/core/RootView'
template = require 'templates/i18n/i18n-home-view'
CocoCollection = require 'collections/CocoCollection'
Courses = require 'collections/Courses'
Article = require 'models/Article'
#Interactive = require 'ozaria/site/models/Interactive'
#Cutscene = require 'ozaria/site/models/Cutscene'
ResourceHubResource = require 'models/ResourceHubResource'

LevelComponent = require 'models/LevelComponent'
ThangType = require 'models/ThangType'
Level = require 'models/Level'
Achievement = require 'models/Achievement'
Campaign = require 'models/Campaign'
#Cinematic = require 'ozaria/site/models/Cinematic'
Poll = require 'models/Poll'

languages = _.keys(require 'locale/locale').sort()
PAGE_SIZE = 100
QUERY_PARAMS = '?view=i18n-coverage&archived=false'

module.exports = class I18NHomeView extends RootView
  id: 'i18n-home-view'
  template: template

  events:
    'change #language-select': 'onLanguageSelectChanged'

  constructor: (options) ->
    super(options)
    @selectedLanguage = me.get('preferredLanguage') or ''

    #-
    @aggregateModels = new Backbone.Collection()
    @aggregateModels.comparator = (m) ->
      return 2 if m.specificallyCovered
      return 1 if m.generallyCovered
      return 0

    project = ['name', 'components.original', 'i18n', 'i18nCoverage', 'slug']

    @thangTypes = new CocoCollection([], { url: "/db/thang.type#{QUERY_PARAMS}", project: project, model: ThangType })
    @components = new CocoCollection([], { url: "/db/level.component#{QUERY_PARAMS}", project: project, model: LevelComponent })
    @levels = new CocoCollection([], { url: "/db/level#{QUERY_PARAMS}", project: project, model: Level })
    @achievements = new CocoCollection([], { url: "/db/achievement#{QUERY_PARAMS}", project: project, model: Achievement })
    @campaigns = new CocoCollection([], { url: "/db/campaign#{QUERY_PARAMS}", project: project, model: Campaign })
    @polls = new CocoCollection([], { url: "/db/poll#{QUERY_PARAMS}", project: project, model: Poll })
    @courses = new Courses()
    #@cinematics = new CocoCollection([], { url: "/db/cinematic#{QUERY_PARAMS}", project: project, model: Cinematic })
    @articles = new CocoCollection([], { url: "/db/article#{QUERY_PARAMS}", project: project, model: Article })
    #@interactive = new CocoCollection([], { url: "/db/interactive#{QUERY_PARAMS}", project: project, model: Interactive })
    #@cutscene = new CocoCollection([], { url: "/db/cutscene#{QUERY_PARAMS}", project: project, model: Cutscene })
    @resourceHubResource = new CocoCollection([], { url: "/db/resource_hub_resource#{QUERY_PARAMS}", project: project, model: ResourceHubResource })
    #for c in [@thangTypes, @components, @levels, @achievements, @campaigns, @polls, @courses, @articles, @interactive, @cinematics, @cutscene, @resourceHubResource]
    for c in [@thangTypes, @components, @levels, @achievements, @campaigns, @polls, @courses, @articles, @resourceHubResource]
      c.skip = 0

      c.fetch({data: {skip: 0, limit: PAGE_SIZE}, cache:false})
      @supermodel.loadCollection(c, 'documents')
      @listenTo c, 'sync', @onCollectionSynced


  onCollectionSynced: (collection) ->
    for model in collection.models
      model.i18nURLBase = switch model.constructor.className
        when 'ThangType' then '/i18n/thang/'
        when 'LevelComponent' then '/i18n/component/'
        when 'Achievement' then '/i18n/achievement/'
        when 'Level' then '/i18n/level/'
        when 'Campaign' then '/i18n/campaign/'
        when 'Poll' then '/i18n/poll/'
        when 'Course' then '/i18n/course/'
        when 'Product' then '/i18n/product/'
        when 'Article' then '/i18n/article/'
        when 'Interactive' then '/i18n/interactive/'
        when 'Cinematic' then '/i18n/cinematic/'
        when 'Cutscene' then '/i18n/cutscene/'
        when 'ResourceHubResource' then '/i18n/resource_hub_resource/'
    getMore = collection.models.length is PAGE_SIZE
    @aggregateModels.add(collection.models)
    @render()

    if getMore
      collection.skip += PAGE_SIZE
      collection.fetch({data: {skip: collection.skip, limit: PAGE_SIZE}})

  getRenderData: ->
    c = super()
    @updateCoverage()
    c.languages = languages
    c.selectedLanguage = @selectedLanguage
    c.collection = @aggregateModels

    covered = (m for m in @aggregateModels.models when m.specificallyCovered).length
    coveredGenerally = (m for m in @aggregateModels.models when m.generallyCovered).length
    total = @aggregateModels.models.length
    c.progress = if total then parseInt(100 * covered / total) else 100
    c.progressGeneral = if total then parseInt(100 * coveredGenerally / total) else 100
    c.showGeneralCoverage = /-/.test(@selectedLanguage ? 'en')  # Only relevant for languages with more than one family, like zh-HANS

    c

  updateCoverage: ->
    selectedBase = @selectedLanguage[..2]
    relatedLanguages = (l for l in languages when _.string.startsWith(l, selectedBase) and l isnt @selectedLanguage)
    for model in @aggregateModels.models
      @updateCoverageForModel(model, relatedLanguages)
      model.generallyCovered = true if _.string.startsWith @selectedLanguage, 'en'
    @aggregateModels.sort()

  updateCoverageForModel: (model, relatedLanguages) ->
    model.specificallyCovered = true
    model.generallyCovered = true
    coverage = model.get('i18nCoverage') ? []

    unless @selectedLanguage in coverage
      model.specificallyCovered = false
      if not _.any((l in coverage for l in relatedLanguages))
        model.generallyCovered = false
        return

  afterRender: ->
    super()
    @addLanguagesToSelect(@$el.find('#language-select'), @selectedLanguage)
    @$el.find('option[value="en-US"]').remove()
    @$el.find('option[value="en-GB"]').remove()

  onLanguageSelectChanged: (e) ->
    @selectedLanguage = $(e.target).val()
    if @selectedLanguage
      # simplest solution, see if this actually ends up being not what people want
      me.set('preferredLanguage', @selectedLanguage)
      me.patch()
    @render()
