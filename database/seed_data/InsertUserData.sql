USE exploremy_dev;

INSERT INTO users
    (email, password_hash, username, city, age, gender, account_status)
VALUES
    ('alice@example.com',   '$2b$11$H74KXxThDLl4phBNt16xzedlwqMjWN8vwSQIpT.6dLrBbAxU.B.Sy', 'alice',   'Kuala Lumpur', 24, 'Female',            'active'),
    ('bob@example.com',     '$2b$11$J96MWs7pvdfeBaLG.clMX.J6TSGM.o.MOUboPilMmsUK/Bi2tls.e', 'bob',     'Singapore',    29, 'Male',              'active'),
    ('carol@example.com',   '$2b$11$l34zEhJu4Ys3AWXJmb8ftOsckA5OtJqhDlk4X4RIlm3OO1P2p1J/q', 'carol',   'Penang',       31, 'Prefer not to say', 'pending_verification'),
    ('dave@example.com',    '$2b$11$/sYQysoXzt/mdIZvvp9vzuWm/I67DfCWa.QjHaClWdVx9jEvSt6NS', 'dave',    'Bangkok',      27, 'Male',              'active'),
    ('erin@example.com',    '$2b$11$WO9RJ9/X6LQiqXlDu8549OnpyDd/hu9ns8f7Xekshz.jD52ngWVee', 'erin',    'Johor Bahru',  22, 'Female',            'pending_verification');