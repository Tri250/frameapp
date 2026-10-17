"""Validate reviewed contribution records and render a static community page."""
from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal
import html
import re
from urllib.parse import urlparse

KINDS = {
    'fix': '问题修复', 'feature': '功能改进', 'test': '测试验证',
    'design': '体验设计', 'docs': '文档翻译', 'review': '代码审查',
}
LOGIN = re.compile(r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?\Z')


def validate(data):
    origin = urlparse(data['repository_url'])
    if (origin.scheme != 'https' or origin.netloc != 'github.com'
            or not re.fullmatch(r'/[\w.-]+/[\w.-]+', origin.path)
            or origin.query or origin.fragment):
        raise ValueError('repository_url must identify one HTTPS GitHub repository')
    date.fromisoformat(data['updated_at'])
    if type(data['accepting_contributions']) is not bool:
        raise ValueError('accepting_contributions must be a boolean')
    maintainers = {login.casefold() for login in data['maintainers']}
    if not maintainers or any(not LOGIN.fullmatch(login) for login in maintainers):
        raise ValueError('At least one valid maintainer is required')
    people = {}
    for person in data['people']:
        login = person['login'].casefold()
        if not LOGIN.fullmatch(login) or login in people:
            raise ValueError('Invalid or duplicate GitHub login')
        if not isinstance(person['name'], str) or not person['name'].strip() or len(person['name']) > 80:
            raise ValueError('Display names must contain 1–80 characters')
        if type(person['display_consent']) is not bool or type(person['featured']) is not bool:
            raise ValueError('Display consent and featured must be booleans')
        people[login] = person
    ids, sources = set(), set()
    for entry in data['entries']:
        if not isinstance(entry['id'], str) or not entry['id'] or entry['id'] in ids:
            raise ValueError('Contribution IDs must be unique')
        ids.add(entry['id'])
        source = urlparse(entry['source'])
        pattern = re.escape(origin.path) + r'/(pull|issues)/[1-9][0-9]*'
        if (source.scheme != 'https' or source.netloc != 'github.com'
                or not re.fullmatch(pattern, source.path) or source.query):
            raise ValueError('Evidence must be a PR or issue in this repository')
        evidence = source.path
        if evidence in sources:
            raise ValueError('Duplicate contribution evidence')
        sources.add(evidence)
        if entry['kind'] not in KINDS or entry['status'] not in {'accepted', 'reverted'}:
            raise ValueError('Unknown kind or status')
        if type(entry['points']) is not int or entry['points'] not in {1, 3, 5, 8}:
            raise ValueError('Contribution value must be 1, 3, 5, or 8')
        if entry['confirmed_by'].casefold() not in maintainers:
            raise ValueError('A configured maintainer must confirm the work')
        if date.fromisoformat(entry['accepted_at']) > date.fromisoformat(data['updated_at']):
            raise ValueError('An accepted contribution cannot be dated in the future')
        if not isinstance(entry['summary'], str) or not entry['summary'].strip():
            raise ValueError('A concrete outcome is required')
        shares, participants = Decimal(0), set()
        for credit in entry['credits']:
            login = credit['login'].casefold()
            if login not in people or login in participants:
                raise ValueError('Credits must name distinct known people')
            participants.add(login)
            share = Decimal(str(credit['share']))
            if not share.is_finite() or share <= 0 or share > 1:
                raise ValueError('Credit shares must be positive and at most 1')
            shares += share
        if shares != 1:
            raise ValueError('Shared credit must add up to exactly 1')
    return people


def ranking(data):
    people = validate(data)
    totals = defaultdict(lambda: {'points': Decimal(0), 'recent': Decimal(0), 'work': []})
    cutoff = date.fromisoformat(data['updated_at']) - timedelta(days=89)
    for entry in data['entries']:
        if entry['status'] != 'accepted':
            continue
        for credit in entry['credits']:
            record = totals[credit['login'].casefold()]
            value = Decimal(entry['points']) * Decimal(str(credit['share']))
            record['points'] += value
            if date.fromisoformat(entry['accepted_at']) >= cutoff:
                record['recent'] += value
            record['work'].append(entry)
    result = []
    for login, record in totals.items():
        person = people[login]
        if person['display_consent'] and person['featured'] and record['points'] > 0:
            result.append({'person': person, **record})
    return sorted(result, key=lambda row: (-row['points'], -row['recent'], row['person']['login'].casefold()))


def number(value):
    return format(value.normalize(), 'f')


def render(data):
    rows = ranking(data)
    repo = html.escape(data['repository_url'], quote=True)
    stamp = html.escape(data['updated_at'])
    cards = []
    previous, rank = None, 0
    for index, row in enumerate(rows, start=1):
        if row['points'] != previous:
            rank = index
        previous = row['points']
        person = row['person']
        name, login = html.escape(person['name']), html.escape(person['login'])
        works = sorted(row['work'], key=lambda work: work['accepted_at'], reverse=True)
        evidence = ''.join(
            f'<li><a href="{html.escape(work["source"], quote=True)}">{html.escape(work["summary"])}</a>'
            f'<small>{KINDS[work["kind"]]} · {html.escape(work["accepted_at"])}</small></li>'
            for work in works[:3]
        )
        kinds = ' · '.join(dict.fromkeys(KINDS[work['kind']] for work in works))
        cards.append(f'''<article class="contributor"><div class="contributor-top"><span class="rank">{rank:02}</span><div class="identity"><a href="https://github.com/{login}" class="person-name">{name}</a><p>@{login} · {kinds}</p></div><div class="credit"><strong>{number(row['points'])}</strong><small>累计贡献分</small></div></div><ul class="evidence">{evidence}</ul><p class="recent">近 90 天 {number(row['recent'])} 分 · 已确认 {len(works)} 项贡献</p></article>''')
    if not cards:
        cards.append('''<div class="community-empty"><span class="empty-mark" aria-hidden="true">＋</span><h2>期待与你一起，<br>让取景更好用。</h2><p>欢迎参与项目。<br>有实际贡献、经确认并同意展示后，名字就有机会出现在这里。</p></div>''')
    status = ('社区已开放，欢迎从你擅长的地方开始。' if data['accepting_contributions'] else '当前暂不接受新贡献，请参阅仓库说明。')
    participation = (f'<a class="community-cta" href="{repo}">前往 GitHub 参与 <span aria-hidden="true">↗</span></a>' if data['accepting_contributions'] else '<p class="community-status">贡献接收已暂停 · 请参阅仓库说明</p>')
    return f'''<p class="meta">榜单更新 {stamp}</p><p class="community-intro">{status}<br>每一次修复、验证和改进，都值得被看见。</p>{participation}<div class="contributors">{''.join(cards)}</div><section id="how"><h2>不只写代码，<br>都能贡献一份力量。</h2><div class="contribution-types"><p><strong>修好一个问题</strong><br>让取景、跟踪和保存更可靠。</p><p><strong>验证一种场景</strong><br>复现问题、补充测试与设备验证。</p><p><strong>打磨一个体验</strong><br>改进设计、文案、文档与翻译。</p><p><strong>审好一份改动</strong><br>提供被采纳的、有依据的审查建议。</p></div></section><section id="rules"><h2>贡献如何被认可</h2><ol><li>工作有可查证的 PR 或 Issue 记录，代码已经合入，其他成果已被采纳。</li><li>维护者根据实际影响确认 1、3、5 或 8 分。同一项工作只计一次，协作完成时按约定分摊。</li><li>榜单展示累计贡献，附带近 90 天的贡献；相同累计分并列。被撤回的成果不再计分。</li><li>至少有一项有效贡献，并同意展示昵称和 GitHub 身份后，才会进入展示名单。代码行数、Star 和无效提交不计分。</li></ol><p class="meta">贡献分是社区认可记录，不代表收入、股权或报酬。展示是可选的，未上榜不会影响你的代码署名。</p></section><section id="contact"><h2>确认记录，或调整展示</h2><p>发现归属遗漏、分值有异议，或希望修改昵称、退出展示？请通过 <a href="{repo}/issues">仓库 Issue</a> 提交公开记录；涉及私人资料时先申请私下联系渠道。</p></section>'''
