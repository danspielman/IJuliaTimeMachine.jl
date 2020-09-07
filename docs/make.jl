using IJuliaTimeMachine
using Documenter

makedocs(;
    modules=[IJuliaTimeMachine],
    authors="Daniel Spielman <daniel.spielman@yale.edu> and contributors",
    repo="https://github.com/danspielman/IJuliaTimeMachine.jl/blob/{commit}{path}#L{line}",
    sitename="IJuliaTimeMachine.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://danspielman.github.io/IJuliaTimeMachine.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/danspielman/IJuliaTimeMachine.jl",
)
