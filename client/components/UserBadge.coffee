React = require('react')
deepcopy = require("deepcopy")
moment = require('moment')
deepEqual = require('deep-equal')

import Grid from 'react-bootstrap/lib/Grid'
import Button from 'react-bootstrap/lib/Button'
import ButtonGroup from 'react-bootstrap/lib/ButtonGroup'

import callApi from '../lib/callApi'

import CfStatus from './CfStatus'
import UserName from './UserName'
import {BigAchieves} from './Achieves'

import styles from './UserBadge.css'

import { GROUPS } from '../lib/informaticsGroups'

import {getClassStartingFromJuly} from '../../client/lib/graduateYearToClass'

class GroupSelector extends React.Component
    constructor: (props) ->
        super(props)
        @handleMove = @handleMove.bind(this)
        @setDormant = @setDormant.bind(this)

    handleMove: (name) ->
        () =>
            await callApi "moveUserToGroup/#{@props.user._id}/#{name}", {}  # empty data to have it POSTed
            await @props.handleReload()
    
    setDormant: () ->
        () =>
            await callApi "setDormant/#{@props.user._id}", {}
            await @props.handleReload()

    render: () ->
        <div>
            {"Переместить в группу: "}
            <ButtonGroup>
                {
                res = []
                a = (el) -> res.push(el)
                for name, id of GROUPS
                    a <Button key={name} active={name==@props.user.userList} onClick={@handleMove(name)}>
                        {name}
                    </Button>
                a <Button key={"dormant"} active={@props.user.dormant} onClick={@setDormant()}>dormant</Button>
                res
                }
            </ButtonGroup>
        </div>
        

export default class UserBadge extends React.Component
    constructor: (props) ->
        super(props)
        @state = @startState(props)
        @handleChange = @handleChange.bind(this)
        @handleGraduateYearChange = @handleGraduateYearChange.bind(this)
        @handleBlChange = @handleBlChange.bind(this)
        @handleCfChange = @handleCfChange.bind(this)
        @handlePaidTillChange = @handlePaidTillChange.bind(this)
        @handlePriceChange = @handlePriceChange.bind(this)
        @handleAchievesChange = @handleAchievesChange.bind(this)
        @handlePasswordChange = @handlePasswordChange.bind(this)
        @handleSubmit = @handleSubmit.bind(this)
        @handleKeyPressed = @handleKeyPressed.bind(this)
        @updateResults = @updateResults.bind(this)

    startState: (props) ->
        return
            graduateYear: props.user.graduateYear || '',
            baseLevel: props.user.level.base || '',
            cfLogin: props.user.cf?.login || '',
            paidTill: if props.user.paidTill then moment(props.user.paidTill).format("YYYY-MM-DD") else ''
            price: if props.user.price? then ''+props.user.price else ''
            achieves: (props.user.achieves || []).join(' ')
            password: ''

    componentDidUpdate: (prevProps, prevState) ->
        newState = @startState(@props)
        oldStartState = @startState(prevProps)
        if !deepEqual(newState, oldStartState)
            @setState(newState)

    handleChange: (field, event) ->
        newState = deepcopy(@state)
        newState[field] = event.target.value
        @setState(newState)

    handleGraduateYearChange: (event) ->
        @handleChange("graduateYear", event)

    handleBlChange: (event) ->
        @handleChange("baseLevel", event)

    handleCfChange: (event) ->
        @handleChange("cfLogin", event)

    handlePaidTillChange: (event) ->
        @handleChange("paidTill", event)

    handlePriceChange: (event) ->
        @handleChange("price", event)

    handleAchievesChange: (event) ->
        @handleChange("achieves", event)

    handlePasswordChange: (event) ->
        @handleChange("password", event)

    handleSubmit: (event) ->
        await callApi('user/' + @props.user._id + '/set',
            graduateYear: @state.graduateYear
            level:
                base: @state.baseLevel
            cf:
                login: @state.cfLogin
            paidTill: @state.paidTill
            price: @state.price
            achieves: @state.achieves
            password: @state.password
        )
        @props.handleReload()

    handleKeyPressed: (e) ->
        if e.key == "Enter"
            @handleSubmit(e)

    updateResults: (e) ->
        await callApi('updateResults/' + @props.user._id)
        @props.handleReload()

    render: () ->
        cls = getClassStartingFromJuly(@props.user.graduateYear)
        <div>
            <h1>
                <UserName user={@props.user} noachieves={true}/>
            </h1>
            <BigAchieves achieves={@props.user.achieves} />
            <blockquote>
                {cls && <div>Класс: {cls}</div>}
                <div>Уровень: {@props.user.level.current}</div>
                { @props.me?.admin &&
                    <div>
                        Уровень на начало полугодия: {@props.user.level.start}
                    </div> }
                <div>Рейтинг: {@props.user.rating}</div>
                <div>Активность: {@props.user.activity.toFixed(1)}</div>
                {
                if @props.user.cf?.rating
                    <div> Codeforces рейтинг: <CfStatus cf={@props.user.cf}/> </div>
                else if @props.explain
                    <div>Логин на codeforces неизвестен. Если вы зарегистированы, сообщите логин мне.</div>
                }

                { @props.me?.admin &&
                    <form className={styles.form} onSubmit={@handleSubmit}>
                        <div>
                            Год выпуска: <input
                                type="text"
                                name="newgraduateYear"
                                value={@state.graduateYear}
                                size="4"
                                onChange={@handleGraduateYearChange}
                                onKeyPress={@handleKeyPressed} />
                        </div>
                        <div>
                            Базовый уровень: <input
                                type="text"
                                name="newLevel"
                                value={@state.baseLevel}
                                size="3"
                                onChange={@handleBlChange}
                                onKeyPress={@handleKeyPressed} />
                        </div>
                        <div>
                            Cf login: <input
                                type="text"
                                name="newLogin"
                                value={@state.cfLogin}
                                size="20"
                                onChange={@handleCfChange}
                                onKeyPress={@handleKeyPressed} />
                        </div>
                        <div>
                            Paid till (YYYY-MM-DD): <input
                                type="text"
                                name="newPaidTill"
                                value={@state.paidTill}
                                size="20"
                                onChange={@handlePaidTillChange}
                                onKeyPress={@handleKeyPressed} />
                            {if @props.user.paidTill 
                                paidTill = moment(@props.user.paidTill).hours(23).minutes(59).seconds(59)
                                paidTillDate = paidTill.format("YYYY-MM-DD")
                                timeLeft = Math.floor(paidTill.diff(moment(), 'days', true))
                                " (на сервере: #{paidTillDate} = #{timeLeft} дней)"
                            }
                        </div>
                        <div>
                            Стоимость: <input
                                type="text"
                                name="newPrice"
                                value={@state.price}
                                size="20"
                                onChange={@handlePriceChange}
                                onKeyPress={@handleKeyPressed} />
                            {if @props.user.price?
                                " (на сервере: #{@props.user.price})"
                            }
                        </div>
                        <div>
                            Ачивки: <input
                                type="text"
                                name="achieves"
                                value={@state.achieves}
                                size="20"
                                onChange={@handleAchievesChange}
                                onKeyPress={@handleKeyPressed} />
                        </div>
                        <div>
                            Пароль: <input
                                type="text"
                                name="password"
                                value={@state.password}
                                size="20"
                                onChange={@handlePasswordChange}
                                onKeyPress={@handleKeyPressed} />
                        </div>
                    </form> }
                { @props.me?.admin && <GroupSelector user={@props.user} handleReload={@props.handleReload}/> }
                { @props.me?.admin && <Button onClick={@updateResults}>Update results</Button> }
            </blockquote>
            { @props.explain &&
                <a href={"/user/" + @props.user._id} target="_blank">Полные результаты</a> }
        </div>