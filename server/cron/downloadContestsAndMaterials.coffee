request = require('request-promise-native')

import Problem from "../models/problem"
import Table from "../models/table"
import Material from "../models/Material"
import User from "../models/user"

import logger from '../log'
import download from '../lib/download'
import getTestSystem from '../testSystems/TestSystemRegistry'

clone = (material) ->
    JSON.parse(JSON.stringify(material))

class MaterialAdder
    constructor: () ->
        @materials = {}
        @contests = []
        @news = []

    addMaterial: (material) ->
        @materials[material._id] = material

    finalizeMaterialsList = (materials) ->
        materials = (m for m in materials when m)
        materials = await Promise.all(materials)
        materials = (m for m in materials when m)
        return materials

    fillPaths: (material, path) ->
        material.path = path
        path = path.concat
            _id: material._id
            title: material.title
        if not material.materials
            logger.error("Have no submaterials #{material}")
        for m in material.materials
            @fillPaths(@materials[m._id], path)

    save: ->
        promises = []
        for id, material of @materials
            promises.push(material.upsert())
        await Promise.all(promises)

    addTable: (id, name) ->
        material = new Material
            _id: id
            type: "table",
            title: name
            content: "/table/all/#{id}"
        @addMaterial(material)

        tree = clone(material)
        tree.type = "link"

        @contests.push
            material: material
            tree: tree

    saveNews: ->
        material = new Material
            _id: "news",
            materials: @news
            path: [{_id: "main", title: "/"}]

        await material.upsert()

    finalize: ->
        @addTable("semester1", "Сводная таблица по семестру 1")
        @addTable("semester2", "Сводная таблица по семестру 2")
        @contests = await finalizeMaterialsList(@contests)

        mainPageMaterial = new Material
            _id: "main"
            order: 0
            type: "level"
            title: "/"
            materials: (m.material for m in @contests)
        @addMaterial(mainPageMaterial)

        @fillPaths(mainPageMaterial, [])
        @save()

        trees = (m.tree for m in @contests)

        treeMaterial = new Material
            _id: "tree",
            materials: trees
        await treeMaterial.upsert()

        @saveNews()

    processProblem: (problem, order) ->
        oldMaterial = await Material.findById(problem._id)
        if oldMaterial?.force
            logger.info("Will not overwrite a forced material #{problem._id}")
            material = oldMaterial
        else
            material = new Material
                _id: problem._id,
                order: order,
                type: "problem",
                title: problem.name,
                content: problem.text,
                materials: []
                isReview: problem.isReview
                
        @addMaterial(material)
        tree = clone(material)
        delete tree.content
        return
            material: material
            tree: tree

    addContest: (order, cid, name, level, problems, deadline) ->
        materials = []
        for prob, i in problems
            materials.push(@processProblem(prob, i))

        materials = await finalizeMaterialsList(materials)
        trees = (m.tree for m in materials)
        materials = ({_id: m.material._id, title: m.material.title} for m in materials)

        material = new Material
            _id: cid
            order: order
            type: "contest"
            indent: 0
            title: name
            materials: materials
        @addMaterial(material)

        tree = clone(material)
        delete tree.indent
        tree.materials = trees
        @contests.push
            material: material
            tree: tree

class ProblemsAdder
    constructor: () ->
        @problems = []
        @tables = []

    finalize: () ->
        for problem in @problems
            await problem.add()
        for table in @tables
            await table.upsert()

    addContest: (order, cid, name, level, problems, deadline) ->
        problemIds = []
        for prob, i in problems
            @problems.push new Problem(
                _id: prob._id,
                letter: prob.letter,
                name: prob.name
                points: prob.points
                isReview: prob.isReview
                deadline: deadline
            )
            problemIds.push(prob._id)
        @tables.push new Table(
            _id: cid,
            name: name,
            problems: problemIds,
            parent: level,
            order: order*100
        )


class ContestDownloader
    constructor: () ->
        @adders = [new ProblemsAdder(), new MaterialAdder()]

    processContest: (order, cid, name, level, testSystem, deadline) ->
        problems = await testSystem.downloadContestProblems(cid)
        for adder in @adders
            await adder.addContest(order, cid, name, level, problems, deadline)
        logger.debug "Downloaded contest ", name

    finalize: () ->
        await Promise.all((adder.finalize() for adder in @adders))


class ShadContestDownloader extends ContestDownloader
    contests:
        "Домашнее задание 0":
            id: '1',
            table: 'semester1',
            deadline: '2018-10-30'
        "Домашнее задание 1": 
            id: '2'
            table: 'semester1',
            deadline: '2018-11-06'
        "Домашнее задание 2": 
            id: '3',
            table: 'semester1',
            deadline: '2018-11-13'
        "Домашнее задание 3": 
            id: '4',
            table: 'semester1',
            deadline: '2018-11-20'
        "Домашнее задание 4": 
            id: '5',
            table: 'semester1',
            deadline: '2018-11-27'
        "Домашнее задание 5": 
            id: '6',
            table: 'semester1',
            deadline: '2018-12-04'
        "Домашнее задание 6": 
            id: '7',
            table: 'semester1',
            deadline: '2018-12-11'
        "Ревью": 
            id: '9'
            table: 'semester1',
            deadline: '2019-01-01'
        "Домашнее задание 2-1": 
            id: '10',
            table: 'semester2',
            deadline: '2019-04-09'            
        "Домашнее задание 2-2": 
            id: '11',
            table: 'semester2',
            deadline: '2019-04-16'            
        "Домашнее задание 2-3": 
            id: '12',
            table: 'semester2',
            deadline: '2019-04-23'            
        "Домашнее задание 2-4": 
            id: '13',
            table: 'semester2',
            deadline: '2019-04-30'            
        "Домашнее задание 2-5": 
            id: '14',
            table: 'semester2',
            deadline: '2019-05-7'
        "Домашнее задание 2-6": 
            id: '15',
            table: 'semester2',
            deadline: '2019-05-14'
        "Ревью 2": 
            id: '16'
            table: 'semester2',
            deadline: '2019-07-01'

    run: ->
        levels = []
        for fullText, cont of @contests
            ejudge = getTestSystem("ejudge")
            console.log fullText, cont.id
            await @processContest(cont * 10 + 1, cont.id, fullText, cont.table, ejudge, cont.deadline)

        await @finalize()

        users = await User.findAll()
        promises = []
        for user in users
            promises.push(User.updateUser(user._id))
        await Promise.all(promises)

running = false

wrapRunning = (callable) ->
    () ->
        if running
            logger.info "Already running downloadContests"
            return
        try
            running = true
            await callable()
        finally
            running = false

export run = wrapRunning () ->
    logger.info "Downloading contests"
    await (new ShadContestDownloader().run())
    await Table.removeDuplicateChildren()
    logger.info "Done downloading contests"