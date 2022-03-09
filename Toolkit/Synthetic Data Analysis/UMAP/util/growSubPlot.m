function growSubPlot(fig, R, C, N, by)
n=1
for r=1:R
    for c=1:C
        ax=subplot(R, C, n, 'parent', fig);
        op=ax.OuterPosition;
        ax.Position=[op(1) op(2) op(3)*by op(4)*by];
        ax.OuterPosition=[op(1) op(2) op(3)*by op(4)*by];
        
        n=n+1;
        if n==N
            return;
        end
    end
end