fs      = require 'fs-extra'
Git     = require 'nodegit'
path    = require 'path'
request = require 'request'
yaml    = require 'js-yaml'

recentProjectsPath = if process.env.LUNA_STUDIO_CONFIG? then process.env.LUNA_STUDIO_CONFIG + '/recent-projects.yml' else './recent-projects.yml'
tutorialsDownloadPath = if process.env.LUNA_STUDIO_TUTORIALS? then  process.env.LUNA_STUDIO_TUTORIALS else '/tmp'
temporaryProject = {
    name: 'unsaved-luna-project',
    path: '/tmp/unsaved-luna-project',
    srcDir: 'src'
    mainFile: 'Main.luna'
    mainContent: 'def main:\n    None'
    }

encoding = 'utf8'

tutorialRequestOpts =
    url: 'https://api.github.com/users/luna-packages/repos'
    headers:
        'User-Agent': 'luna-studio'

loadRecentNoCheck = (callback) =>
    fs.readFile recentProjectsPath, encoding, (err, data) =>
        recentProjectsPaths = []
        if err
            console.log err
        else
            parsed = yaml.safeLoad(data)
            if parsed?
                recentProjectsPaths = parsed
        callback recentProjectsPaths

createTemporary = (callback) =>
    fs.remove temporaryProject.path, (err) =>
        console.log err
        fs.mkdir temporaryProject.path, (err) =>
            if err then callback err
            srcPath = path.join temporaryProject.path, temporaryProject.srcDir
            fs.mkdir srcPath, (err) =>
                if err then callback err
                mainPath = path.join srcPath, temporaryProject.mainFile
                fs.writeFile mainPath, temporaryProject.mainContent, (err) =>
                    if err then callback err
                    callback()

module.exports =

    temporaryProject:
        path: path.join temporaryProject.path, temporaryProject.srcDir, temporaryProject.mainFile
        open: (callback) =>
            createTemporary (err) =>
                if err then throw err
                atom.project.setPaths [temporaryProject.path]
                if callback then callback()

    recent:
        load: (callback) =>
            loadRecentNoCheck (recentProjectsPaths) =>
                recentProjectsPaths.forEach (recentProjectPath) =>
                    fs.access recentProjectPath, (err) =>
                        if not err
                            callback recentProjectPath

        add: (recentProjectPath) =>
            loadRecentNoCheck (recentProjectsPaths) =>
                pos = recentProjectsPaths.indexOf(recentProjectPath);
                if pos != -1
                    recentProjectsPaths.splice(pos, 1)
                recentProjectsPaths.unshift(recentProjectPath)
                data = yaml.safeDump(recentProjectsPaths)
                fs.writeFile recentProjectsPath, data, encoding, (err) =>
                    if err?
                        console.log err
    tutorial:
        list: (callback) =>
            try
                request.get tutorialRequestOpts, (err, response, body) =>
                    parsed = yaml.safeLoad(body)
                    repos = []
                    if parsed?
                        for repo in parsed
                            repos.push
                                name: repo.name
                                description: repo.description
                                uri: repo.html_url
                                thumb: ('https://raw.githubusercontent.com/luna-packages/' + repo.name + '/master/thumb.png')
                    callback repos
            catch error
                atom.confirm
                    message: "Error while getting tutorials"
                    detailedMessage: error.message
                    buttons:
                        Ok: ->

        open: (tutorial, progress, finalize) ->
            dstPath = tutorialsDownloadPath + '/' + tutorial.name
            cloneOpts =
                fetchOpts:
                    callbacks:
                        certificateCheck: => 1
                        credentials: (url, userName, bla) =>
                            Git.Cred.sshKeyFromAgent(userName)
                        transferProgress: (stats) =>
                            p = (stats.receivedObjects() + stats.indexedObjects()) / (stats.totalObjects() * 2)
                            try
                              progress p
                            catch error
                              console.log error

            fs.access dstPath, (err) =>
                if err
                    Git.Clone(tutorial.uri, dstPath, cloneOpts)
                        .then((repo) =>
                            atom.project.setPaths [dstPath]
                            finalize())
                        .catch((error) =>
                            atom.confirm
                                message: "Error while cloning tutorial"
                                detailedMessage: error.message
                                buttons:
                                    Ok: ->
                            finalize())
                else
                    atom.project.setPaths [dstPath]
                    finalize()
